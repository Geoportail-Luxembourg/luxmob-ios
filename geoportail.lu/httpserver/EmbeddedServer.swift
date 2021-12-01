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
        server.route(.GET, "/check", checkUpdate)
        server.route(.PUT, "/map/:mapName", updateMap)
        server.route(.DELETE, "/map/:mapName", deleteMap)
        let offline = Bundle.main.url(forResource: "offline", withExtension: nil)!
        server.serveDirectory(offline, "/")
        
        try! server.start(port: port)
    }
    
    private func checkUpdate(request: HTTPRequest) -> HTTPResponse {
        
        do {
            let mcm = try MbTilesCacheManager()
            let resourcesMeta = try mcm.getLayersStatus()
            
            let resData = try JSONSerialization.data(withJSONObject: resourcesMeta, options: [])
            //let resJSONtxt = try String(data:resData, encoding:.utf8)
            //let json = try JSONEncoder().encode(resourcesMeta)
            //return buildHttpJsonResponse(json: "resourcesMeta".data(using: //String.Encoding.utf8)!)
            return buildHttpJsonResponse(json: resData)
        } catch {
            return buildHttpJsonErrorResponse(message: "Cannot generate check based on resource meta.")
        }
    }
    
    private func updateMap(request: HTTPRequest) -> HTTPResponse {
        guard let mapName = request.params["mapName"], mapName.isEmpty else {
            return HTTPResponse(.notFound, content: "Cannot find this map")
        }
        if (MbtilesSource.exists(tileset: mapName)) {
            
        }
        return HTTPResponse(.notFound, content: "cannot find map \(mapName)")
    }
    
    private func deleteMap(request: HTTPRequest) -> HTTPResponse {
        guard let mapName = request.params["mapName"], mapName.isEmpty else {
            return HTTPResponse(.notFound, content: "Cannot find this map")
        }
        return HTTPResponse(content: "plop \(mapName)")
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
