//
//  MbtilesCacheManager.swift
//  geoportail.lu
//
//  Created by camptocamp on 25/11/2021.
//  Copyright © 2021 Camptocamp. All rights reserved.
//

import Foundation

// Allow distant to be requested synchronously (yes...)
extension URLSession {
   func syncRequest(with request: URLRequest) -> (Data?, URLResponse?, Error?) {
      var data: Data?
      var response: URLResponse?
      var error: Error?
      
      let dispatchGroup = DispatchGroup()
      let task = dataTask(with: request) {
         data = $0
         response = $1
         error = $2
         dispatchGroup.leave()
      }
      dispatchGroup.enter()
      task.resume()
      dispatchGroup.wait()
      
      return (data, response, error)
   }
}

enum RessourceError: Error {
    case runtimeError(String)
}

extension Encodable {
  func asDictionary() throws -> [String: [String: Any?]] {
    let data = try JSONEncoder().encode(self)
      guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: [String: Any]] else {
        throw RessourceError.runtimeError("Cannot transform to dictionary.")
    }
    return dictionary
  }
}

/* Data structure dedicated to represent JSON value*/
struct AbstractResources: Codable {
    let version: String
    let sources: Array<String>
}

struct ResourceMeta: Codable {
    let omt_topo_geoportail_lu: AbstractResources
    let omt_geoportail_lu: AbstractResources
    let hillshade_lu: AbstractResources
    let contours_lu: AbstractResources
    let resources: AbstractResources
    let fonts: AbstractResources
    let sprites: AbstractResources
    
    enum CodingKeys: String, CodingKey {
        case omt_topo_geoportail_lu = "omt-topo-geoportail-lu"
        case omt_geoportail_lu = "omt-geoportail-lu"
        case hillshade_lu = "hillshade-lu"
        case contours_lu = "contours-lu"
        case resources
        case fonts
        case sprites
    }
}

enum DlState: String { case UNKNOWN, IN_PROGRESS, DONE, FAILED }

class MbTilesCacheManager {
    let session = URLSession(configuration: .ephemeral)
    var resourceMeta: ResourceMeta?
    var metaFailed: Bool = false
    let downloadUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("dl", isDirectory: true)
    var dlStatus: [String: [String: DlState]] = [:]
    var dlJobs: [String: [String: URLSessionTask]] = [:]
    var dlVersions: [String: String] = [:]
    var copyQueue: [String: [String: URL]] = [:]

    public func downloadMeta() throws -> Void {
        let url = URL(string: "https://vectortiles-sync.geoportail.lu/metadata/resources.meta")
        var data: Foundation.Data?
        var response: URLResponse?
        var error: Error?
        //var (data, response, error) = session.syncRequest(with: resourcesUrl)
        let sem = DispatchSemaphore.init(value: 0)
        let dataTask = session.dataTask(with: url!, completionHandler: { d, u, e in
            data = d
            response = u
            error = e
            sem.signal()
        })

        dataTask.resume()
        sem.wait()
        if let error = error {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[CLIENT]", "Request failed - status:", statusCode, "- error: \(error)")
            metaFailed = true
            throw RessourceError.runtimeError("Cannot download resource")
        } else {
            do {
                self.resourceMeta = try JSONDecoder().decode(ResourceMeta.self, from: data!)
                metaFailed = false
            } catch {
                metaFailed = true
                throw RessourceError.runtimeError("Cannot download resource")
            }
        }
    }

    public func hasData(resName: String) -> Bool {
        return (try? resourceMeta?.asDictionary().keys.contains(resName)) ?? false
    }
    public func getLocalMeta(resName: String) -> NSDictionary? {
        let versionStream = InputStream(url: downloadUrl.appendingPathComponent("versions/" + resName + ".meta", isDirectory: false))!
        versionStream.open()
        return try? JSONSerialization.jsonObject(with: versionStream) as? NSDictionary
    }

    public func saveMeta(resName: String, version: String, sources: [String]) {
        let versionStream = OutputStream(url: downloadUrl.appendingPathComponent("versions/" + resName + ".meta", isDirectory: false), append: false)!
        versionStream.open()
        var err: NSError?
        let meta : [String: Any] = ["version": version, "sources": sources]
        JSONSerialization.writeJSONObject(meta, to: versionStream, error: &err)
    }

    public func updateRes(resName:String) -> Bool {
        if dlStatus[resName]?.values.contains(.IN_PROGRESS) ?? false {
            return false
        }
        let meta = try! resourceMeta?.asDictionary()[resName]
        let resSources = meta?["sources"] as? [String] ?? []
        dlVersions[resName] = meta?["version"] as? String

        // cancel old jobs
        if self.dlJobs[resName] != nil {
            self.dlJobs[resName]!.values.forEach({ (task: URLSessionTask) in
                guard task.state != .running else {
                    return task.cancel()
                }
            })
        }
        self.copyQueue[resName] = [:]
        var prevJob: URLSessionTask? = nil
        var jobs: [String: URLSessionTask] = [:]
        var status: [String: DlState] = [:]
        for raw_res in resSources {
            // percent encode string so that spaces are handled correctly
            let res = raw_res.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let job = session.downloadTask(with: URL(string: res)!, completionHandler:dlHandlerGenerator(resName: resName, dlSource: res, prevJob: prevJob))
            status[res] = .IN_PROGRESS
            jobs[res] = job
            prevJob = job
        }
        self.dlJobs[resName] = jobs
        self.dlStatus[resName] = status
        if prevJob != nil {
            prevJob!.resume()
        }
//        jobs.values.forEach { (task: URLSessionTask) in
//            task.resume()
//        }
        return true
    }

    private func dlHandlerGenerator(resName: String, dlSource: String, prevJob: URLSessionTask?) -> ((URL?,  URLResponse?, Error?) -> Void) {
        return { (url: URL?, resp: URLResponse?, err: Error?) -> Void in
            if err != nil {
                self.dlStatus[resName]![dlSource] = .FAILED
                (self.dlJobs[resName] ?? [:]).forEach({ (key: String, task: URLSessionTask) in
                    if self.dlStatus[resName]![key] == .IN_PROGRESS {
                        task.cancel()
                    }
                })
                self.dlJobs[resName] = [:]
            }
            else {
                self.dlStatus[resName]![dlSource] = .DONE
                self.copyQueue[resName]![dlSource] = url!
                // if all download jobs for this resource package are done:
                // copy resources to destination folder
                if (prevJob != nil) {
                    prevJob!.resume()
                }
//                if self.dlStatus[resName]?.values.allSatisfy({ (status: DlState) in
//                    status == .DONE
//                }) ?? false {
                else {
                    self.saveMeta(resName: resName, version: self.dlVersions[resName]!, sources: Array(self.copyQueue[resName]!.keys))
                    self.copyQueue[resName]?.forEach({ (key: String, url: URL) in
                        let fromUrl = URL(string: key)
                        let file = fromUrl!.path
                        let toUrl = self.downloadUrl.appendingPathComponent(file, isDirectory: false)
                        let fm = FileManager()
                        try! fm.createDirectory(at: toUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
                        if fm.fileExists(atPath: toUrl.path) { try! fm.removeItem(at: toUrl)}
                        try! fm.moveItem(at: url, to: toUrl)
                    })
                    self.dlJobs[resName] = [:]
                }
            }
        }
    }

    public func getStatus(resName:String) -> DlState {
        // use status dictionary to check for running jobs
        if self.dlStatus[resName]?.contains(where: { (key: String, value: DlState) in
            if case .IN_PROGRESS = value {return true} else {return false}
        }) ?? false {
            return .IN_PROGRESS
        }
        else if self.dlStatus[resName]?.contains(where: { (key: String, value: DlState) in
            if case .FAILED = value {return true} else {return false}
        }) ?? false {
            return .FAILED
        }
        else if self.dlStatus[resName]?.allSatisfy({ (key: String, value: DlState) in
            if case .DONE = value {return true} else {return false}
        }) ?? false {
            return .DONE
        }
        return .UNKNOWN
    }

    public func computeSizeFromPaths(paths: [URL]) -> Int64 {
        let fm = FileManager()
        var totalSize: Int64 = 0
        paths.forEach { url in
            do {
                totalSize += Int64(NSDictionary(dictionary: try fm.attributesOfItem(atPath: url.path)).fileSize())
            }
            catch {}
        }
        return totalSize
    }

    public func getSize(status: DlState, resName: String) -> Int64 {
        // for not running downloads, check resource size in filesysystem
        if status != .IN_PROGRESS {
            let urls: [String] = getLocalMeta(resName: resName)?["sources"] as? [String] ?? []
            let paths = urls.map({ (url: String) in
                return downloadUrl.appendingPathComponent(URL(string: url)!.path, isDirectory: false)
            })
            return computeSizeFromPaths(paths: paths)
        }
        // for running jobs use progress meter of jobs
        let jobs = self.dlJobs[resName]
        var totalBytes: Int64 = 0
        jobs?.forEach({ (key: String, value: URLSessionTask) in
            totalBytes += value.countOfBytesReceived
        })
        return totalBytes
    }

    public func getLayersStatus() throws -> [String: [String: Any?]]{
        do {
            var dictResourceMeta = try resourceMeta.asDictionary()
            for (key, val) in dictResourceMeta {
                let status = getStatus(resName: key)
                dictResourceMeta[key] =
                ["status": status.rawValue,
                 "filesize": getSize(status: status, resName:key),
                 "current": getLocalMeta(resName: key)?["version"] as? String as Any?,
                 "available": (
                    metaFailed ?
                    nil : val["version"]
                 ) as? String as Any?
                ]
            }
            return dictResourceMeta
        } catch {
            throw RessourceError.runtimeError("Missing ressource")
        }
    }

    public func deleteRes(resName: String) throws -> Bool {
        enum ResourceError: Error {
            case metaNotFound(String)
        }
        var errorsFound = false
        let meta = getLocalMeta(resName: resName)
        guard meta != nil else {throw ResourceError.metaNotFound("")}
        let fm = FileManager()
        for res in ((meta!["sources"] ?? []) as! [String]) {
            let fromUrl = URL(string: res)
            let file = fromUrl!.path
            let toUrl = self.downloadUrl.appendingPathComponent(file, isDirectory: false)
            do {
                try fm.removeItem(at: toUrl)
            }
            catch {
                errorsFound = true
            }
        }
        try fm.removeItem(at: downloadUrl.appendingPathComponent("versions/" + resName + ".meta", isDirectory: false))
        return errorsFound
    }
}
