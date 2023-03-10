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

public enum DlState: String { case UNKNOWN, IN_PROGRESS, DONE, FAILED }

class SafeStatusDict<T> {
    var statusDict: [String: [String: T]] = [:]
    private let lockQueue = DispatchQueue(label: "name.lock.queue")

    public func set(mainKey: String, subKey: String, value: T?) {
        self.lockQueue.async {
            if self.statusDict[mainKey] == nil {
                self.statusDict[mainKey] = [:]
            }
            self.statusDict[mainKey]![subKey] = value
        }
    }

    public func get(mainKey: String, subKey: String) -> T? {
        var val: T?
        self.lockQueue.sync {
            val = self.statusDict[mainKey]?[subKey]
        }
        return val
    }

    public func getDict(mainKey: String) -> [String: T]? {
        var val: [String: T]?
        self.lockQueue.sync {
            val = self.statusDict[mainKey]
        }
        return val
    }

    public func reset(mainKey: String) {
        DispatchQueue.global().async {
            self.lockQueue.async {
                self.statusDict[mainKey] = [:]
            }
        }
    }

    public func resetAll() {
        DispatchQueue.global().async {
            self.lockQueue.async {
                self.statusDict = [:]
            }
        }
    }
}

public class MbTilesCacheManager {
    var metaUrl: String = "https://vectortiles-sync.geoportail.lu/metadata/resources.meta"
    let session = URLSession(configuration: .ephemeral)
    var resourceMeta: ResourceMeta?
    var metaFailed: Bool = false
    let fm = FileManager()
    let downloadUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("dl", isDirectory: true)
    var dlStatus: SafeStatusDict = SafeStatusDict<DlState>() //[String: [String: DlState]] = [:]
    var dlJobs: SafeStatusDict = SafeStatusDict<URLSessionTask>() //[String: [String: URLSessionTask]] = [:]
    var dlVersions: SafeStatusDict = SafeStatusDict<String>() //[[String: String] = [:]
    var copyQueue: SafeStatusDict = SafeStatusDict<URL>() //[String: [String: URL]] = [:]

    init() {
    }

    public init(metaUrl: String) {
        self.metaUrl = metaUrl
    }

    public func downloadMeta() throws -> Void {
        let url = URL(string: self.metaUrl)
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
        let metaUrl = downloadUrl.appendingPathComponent("versions/" + resName + ".meta", isDirectory: false)
        try! fm.createDirectory(at: metaUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
        let versionStream = OutputStream(url: metaUrl, append: false)!
        versionStream.open()
        var err: NSError?
        let meta : [String: Any] = ["version": version, "sources": sources]
        JSONSerialization.writeJSONObject(meta, to: versionStream, error: &err)
        versionStream.close()
    }

    public func updateRes(resName:String) -> Bool {
        if dlStatus.getDict(mainKey: resName)?.values.contains(.IN_PROGRESS) ?? false {
            if !(dlStatus.getDict(mainKey: resName)?.values.contains(.FAILED) ?? true) {
                return false
            }
        }
        let meta = try! resourceMeta?.asDictionary()[resName]
        let resSources = meta?["sources"] as? [String] ?? []
        dlVersions.set(mainKey: resName, subKey: "ver", value: meta?["version"] as? String ?? "")

        // cancel old jobs
        self.dlJobs.getDict(mainKey: resName)?.values.forEach({ (task: URLSessionTask) in
            guard task.state != .running else {
                return task.cancel()
            }
        })
        self.dlJobs.reset(mainKey: resName)
        self.dlStatus.reset(mainKey: resName)
        self.copyQueue.reset(mainKey: resName)
        var prevJob: URLSessionTask? = nil
        for raw_res in resSources {
            // percent encode string so that spaces are handled correctly
            let res = raw_res.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let job = session.downloadTask(with: URL(string: res)!, completionHandler:dlHandlerGenerator(resName: resName, dlSource: res, prevJob: prevJob))
            self.dlJobs.set(mainKey: resName, subKey: res, value: job)
            self.dlStatus.set(mainKey: resName, subKey: res, value: .IN_PROGRESS)
            prevJob = job
        }
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
                self.dlStatus.set(mainKey: resName, subKey: dlSource, value: .FAILED)
                self.dlJobs.getDict(mainKey: resName)?.forEach({ (key: String, task: URLSessionTask) in
                    if self.dlStatus.get(mainKey: resName, subKey: key) == .IN_PROGRESS {
                        task.cancel()
                        self.dlStatus.set(mainKey: resName, subKey: key, value: .UNKNOWN)
                    }
                })
                self.dlJobs.reset(mainKey: resName)
            }
            else {
                self.dlStatus.set(mainKey: resName, subKey: dlSource, value: .DONE)
                self.copyQueue.set(mainKey: resName, subKey: dlSource, value: url)
                let fromUrl = URL(string: dlSource)
                let file = fromUrl!.path
                let toUrl = self.downloadUrl.appendingPathComponent(file, isDirectory: false)
                if ((url) != nil) {
                    try! self.fm.createDirectory(at: toUrl.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if self.fm.fileExists(atPath: toUrl.path) { try! self.fm.removeItem(at: toUrl)}
                    if self.fm.fileExists(atPath: url!.path) { try! self.fm.moveItem(at: url!, to: toUrl) }
                }
                // if all download jobs for this resource package are done:
                // set version metadata
                if (prevJob != nil) {
                    prevJob!.resume()
                }
                else {
                    // check if all files are downloaded
                    if self.copyQueue.getDict(mainKey: resName)?.allSatisfy({ (key: String, value: URL) in
                        let fromUrl = URL(string: key)
                        let file = fromUrl!.path
                        let toUrl = self.downloadUrl.appendingPathComponent(file, isDirectory: false)
                        return self.fm.fileExists(atPath: toUrl.path)
                    }) ?? false {
                        // save version metadata
                        self.saveMeta(resName: resName, version: self.dlVersions.get(mainKey: resName, subKey: "ver")!, sources: Array(self.copyQueue.getDict(mainKey: resName)!.keys))
                        self.copyQueue.reset(mainKey: resName)
                    }
                    self.dlJobs.reset(mainKey: resName)
                }
            }
        }
    }

    public func getStatus(resName:String) -> DlState {
        // use status dictionary to check for running jobs
        if self.dlStatus.getDict(mainKey: resName)?.contains(where: { $1 == .FAILED }) ?? false {
            return .FAILED
        }
        else if self.dlStatus.getDict(mainKey: resName)?.contains(where: { $1 == .IN_PROGRESS }) ?? false {
            return .IN_PROGRESS
        }
        else if self.dlStatus.getDict(mainKey: resName)?.allSatisfy({ $1 == .DONE }) ?? false {
            return .DONE
        }
        return .UNKNOWN
    }

    public func computeSizeFromPaths(paths: [URL]) -> Int64 {
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
        var totalBytes: Int64 = 0
        self.dlJobs.getDict(mainKey: resName)?.forEach({ (key: String, value: URLSessionTask) in
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
