//
//  EmbeddedServer.swift
//  geoportail.lu
//
//  Created by Camptocamp on 01.07.20.
//  Copyright © 2020 Camptocamp. All rights reserved.
//

import Foundation
import Telegraph

public class EmbeddedServer {
    let server: Server
    let mcm = MbTilesCacheManager()
    let downloadUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("dl", isDirectory: true)

    public init(port: Int) {
        let caCertificateURL = Bundle.main.url(forResource: "ca", withExtension: "der")!
        let caCertificate = Certificate(derURL: caCertificateURL)!
        
        let identityURL = Bundle.main.url(forResource: "localhost", withExtension: "p12")!
        let identity = CertificateIdentity(p12URL: identityURL, passphrase: "test")!
        
        server = Server(identity: identity, caCertificates: [caCertificate])
        
        server.httpConfig.requestHandlers.insert(HTTPCORSHandler(), at: 0)
        server.httpConfig.requestHandlers.insert(HTTPContentTypeHandler(), at: 0)
        server.httpConfig.requestHandlers.insert(HTTPMbtileHandler(), at: 0)
        server.route(.GET, "ping") {
            (.ok, "pong")
        }
        server.route(.GET, "/test_api.html", testApi)
        server.route(.GET, "/static/*", getStaticFile)
        server.route(.GET, "/check", checkUpdate)
        server.route(.PUT, "/map/:mapName", updateMap)
        server.route(.DELETE, "/map/:mapName", deleteMap)
        let offline = Bundle.main.url(forResource: "offline", withExtension: nil)!
        server.serveDirectory(offline, "/")

        copyFromBundle()

        try! server.start(port: port)
    }
    
    private func testApi(request: HTTPRequest) -> HTTPResponse {
        let response = HTTPResponse()
        //response.headers.contentType = "text/html"
        response.body = Data("""
        <html>
        <script>
        function gc() {
          fetch("https://127.0.0.1:8765/check")
            .then(data=>console.log(data));
        }
        function upd() {
          fetch("https://127.0.0.1:8765/map/contours-lu", {method: "PUT"})
            .then(data=>console.log(data));
          fetch("https://127.0.0.1:8765/map/resources", {method: "PUT"})
            .then(data=>console.log(data));
        }
        function tile() {
          fetch("https://127.0.0.1:8765/?x=529&y=348&z=10&layer=contours-lu&format=pbf", {method: "GET"})
            .then(data=>console.log(data));
        }
        function static_style() {
          fetch("https://127.0.0.1:8765/static/styles/roadmap/style.json", {method: "GET"})
            .then(data=>console.log(data));
        }
        function static_data0() {
          fetch("https://127.0.0.1:8765/static/data/omt-geoportail-lu.json", {method: "GET"})
            .then(data=>console.log(data));
        }
        function static_data() {
          fetch("https://127.0.0.1:8765/static/data/contours-lu.json", {method: "GET"})
            .then(data=>console.log(data));
        }
        function del_res() {
          fetch("https://127.0.0.1:8765/map/contours-lu", {method: "DELETE"})
            .then(data=>console.log(data));
          fetch("https://127.0.0.1:8765/map/sprites", {method: "DELETE"})
            .then(data=>console.log(data));
        }
      </script>
      <body>
      <big><big>
      <button type="button" onclick='gc()'>test</button><br>
      <button type="button" onclick='upd()'>update</button><br>
      <button type="button" onclick='tile()'>get tile</button><br>
      <button type="button" onclick='static_style()'>get style</button><br>
      <button type="button" onclick='static_data0()'>get data0</button><br>
      <button type="button" onclick='static_data()'>get data</button><br>
      <br><br>
      <button type="button" onclick='del_res()'>delete</button><br>
      <a href="#" onclick="gc()">check</a>
      </big></big>
      </body>
      </html>
      """.utf8)
        //response.headers.contentType = "text/html; charset=UTF-8"
        //response.headers.accessControlAllowOrigin = "*"
        return response
    }

    public func getStaticFile(request: HTTPRequest) -> HTTPResponse {
        let resourcePathRaw = request.uri.relativePath(from: "/static")
        let resourcePath = resourcePathRaw!.replacingOccurrences(of: "/static", with: "")
            .replacingOccurrences(of: "/style.json", with: ".json")
        let response = HTTPResponse()
        response.headers.accessControlAllowOrigin = "*"
        let fm = FileManager()
        // debug info
        let exists = fm.fileExists(atPath: downloadUrl.appendingPathComponent(resourcePath, isDirectory: false).path)
        do {
            let data = fm.contents(atPath: downloadUrl.appendingPathComponent(resourcePath, isDirectory: false).path)
            guard (data != nil) else { throw RessourceError.runtimeError("")}
            var resourceBytes: Data = data ?? Data("".utf8)
            if resourcePath.contains(".json") {
                resourceBytes = try replaceUrls(data: data, resourcePath: resourcePath)
            }
            if resourcePath.contains("data/") || resourcePath.contains("styles/") {
                response.headers.cacheControl = "no-store"
            }
            response.headers.contentLength = resourceBytes.count
            response.body = resourceBytes
        }
        catch {
            response.status = HTTPStatus(code: 404, phrase: "Resource not found")
            response.body = Data("".utf8)
        }
        return response
    }

    private func replaceUrls(data:Data?, resourcePath: String) throws -> Data {
        var resString: String = String(data: data!, encoding: .utf8)!
        let fm = FileManager()
        
        if resourcePath.contains("styles/") {
            if fm.fileExists(atPath: downloadUrl.appendingPathComponent(resourcePath, isDirectory: false).path) {

                let re = try! NSRegularExpression(pattern: "mbtiles://\\{(.*)\\}")
                let rr = NSRange(resString.startIndex..<resString.endIndex,
                                      in: resString)
                //resString = re.stringByReplacingMatches(in: String(data: data!, encoding: .utf8)!, range: NSRange(), withTemplate: "blou")
                while case let res = re.firstMatch(in: resString, range: rr), res != nil {
                    let groupValue = (resString as NSString).substring(with: res!.range(at: 1))
                    let replaceValue: String
                    if fm.fileExists(atPath: downloadUrl.appendingPathComponent("data/" + groupValue + ".json", isDirectory: false).path) {
                        replaceValue = "https://127.0.0.1:8765/static/data/" + groupValue + ".json"
                    }
                    else {
                        replaceValue = "https://vectortiles.geoportail.lu/data/" + groupValue + ".json"

                    }
                    resString.replaceSubrange(Range(res!.range, in: resString)!, with: replaceValue)
                }
                resString = resString.replacingOccurrences(of: "\"{fontstack}/{range}.pbf", with: "\"https://127.0.0.1:8765/static/fonts/{fontstack}/{range}.pbf")
            }
        }
        if resourcePath.contains("data/") {
            let mapName = resourcePath.suffix(from: resourcePath.index(after: resourcePath.lastIndex(of: "/")!)).replacingOccurrences(of: ".json", with: "")
            var tilesName: String
            switch mapName {
            case "omt-geoportail":
                tilesName = "tiles_luxembourg"
            case "omt-topo-geoportail":
                tilesName = "topo_tiles_luxembourg"
            case "topo":
                tilesName = "topo_tiles_luxembourg"
            default:
                tilesName = mapName
            }
            try! fm.contentsOfDirectory(atPath: downloadUrl.appendingPathComponent("mbtiles/", isDirectory: true).path)
            if fm.fileExists(atPath: downloadUrl.appendingPathComponent("mbtiles/" + tilesName + ".mbtiles", isDirectory: false).path) {
                let re = try! NSRegularExpression(pattern: "https://vectortiles.geoportail.lu/data/" + mapName + "/\\{z\\}/\\{x\\}/\\{y\\}.(pbf|png)")
                let rr = NSRange(resString.startIndex..<resString.endIndex, in: resString)
                while case let res = re.firstMatch(in: resString, range: rr), res != nil {
                    resString.replaceSubrange(Range(res!.range, in: resString)!, with: "https://localhost:8765/mbtiles?layer=" + mapName + "&z={z}&x={x}&y={y}&format=" + (resString as NSString).substring(with: res!.range(at: 1)))
                }
            }
        }
        return Data(resString.utf8)
    }

    public func copyFromBundle() -> Void {
        let resUrl = Bundle.main.resourceURL?.appendingPathComponent("offline", isDirectory: true)
        let fm = FileManager()
        // temporary clean up before launch
        try! fm.removeItem(atPath: downloadUrl.path)
        if !fm.fileExists(atPath: downloadUrl.path) {
            try! fm.copyItem(atPath: resUrl!.path, toPath: downloadUrl.path)
        }
    }

    private func checkUpdate(request: HTTPRequest) -> HTTPResponse {

        do {
            try mcm.downloadMeta()
            let resourcesMeta = try mcm.getLayersStatus()

            let resData = try JSONSerialization.data(withJSONObject: resourcesMeta, options: [])
            return buildHttpJsonResponse(json: resData)
        } catch {
            return buildHttpJsonErrorResponse(message: "Cannot generate check based on resource meta.")
        }
    }

    private func updateMap(request: HTTPRequest) -> HTTPResponse {
        let mapName = request.params["mapName"] ?? ""
        do {
            try mcm.downloadMeta()
            guard mcm.hasData(resName: mapName) else {
                return HTTPResponse(.notFound, content: "Cannot find this map")
            }
            let launchedSuccessfully = mcm.updateRes(resName: request.params["mapName"]!)
            if (launchedSuccessfully) {
                return HTTPResponse(.accepted, content: "Download of dataset " + request.params["mapName"]! + " launched successfully.")
            }
            else {
                return HTTPResponse(.conflict, content: "ERROR: Download of dataset " + request.params["mapName"]! + " is already in progress, cannot launch another download simultaneously.")
            }
        } catch {
            return HTTPResponse(.notFound, content: "Cannot find update - is the network connection running?")
        }
        return HTTPResponse(.notFound, content: "cannot find map \(mapName)")
    }

    private func deleteMap(request: HTTPRequest) -> HTTPResponse {
        let mapName = request.params["mapName"]
        let response: HTTPResponse

        if mapName != nil {
            do {
                try mcm.deleteRes(resName: mapName!)
                response = HTTPResponse(content: "Deleted package " + mapName! + ".\n")
            }
            catch {
                response = HTTPResponse(.notFound, content: "Map not found.\n")
            }
        }
        else {
           return HTTPResponse(.notFound, content: "No resource name given")
        }
        response.headers.accessControlAllowOrigin = "*"
        response.headers.cacheControl = "no-store"
        return response
        // return HTTPResponse(content: "plop \(mapName)")
    }

    private func buildHttpJsonResponse(json: Data) -> HTTPResponse {
        let response = HTTPResponse()
        response.headers.contentType = "application/json"
        response.body = json
        return response
    }
    private func buildHttpJsonErrorResponse(message: String) -> HTTPResponse {
        let response = HTTPResponse()
        response.status = .internalServerError
        response.body = try! JSONEncoder().encode(["error": message])
        return response
    }
}
