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
  func asDictionary() throws -> [String: [String: Any]] {
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

class MbTilesCacheManager {
    let session = URLSession(configuration: .ephemeral)
    var resourceMeta: ResourceMeta?
    
    init() throws {
        let resourcesUrl = URLRequest(url: URL(string: "https://vectortiles-sync.geoportail.lu/metadata/resources.meta")!)
        let (data, response, error) = session.syncRequest(with: resourcesUrl)
        if let error = error {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[CLIENT]", "Request failed - status:", statusCode, "- error: \(error)")
        } else {
            do {
                self.resourceMeta = try JSONDecoder().decode(ResourceMeta.self, from: data!)
            } catch {
                throw RessourceError.runtimeError("Cannot download resource")
            }
        }
    }
    public func getLayersStatus() throws -> [String: [String: Any]]{
        do {
            let dictResourceMeta = try resourceMeta.asDictionary()
            let layerStatus = dictResourceMeta.mapValues { (val: Dictionary) -> Dictionary in
                ["status": "sdf",
                 "filesize": "lol",
                 "current": "x",
                 "available": val["version"]
                ]
            }
            return layerStatus
        } catch {
            throw RessourceError.runtimeError("Missing ressource")
        }
    }
}
