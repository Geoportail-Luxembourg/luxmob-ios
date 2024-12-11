//
//  HTTPContentTypeHandler.swift
//  geoportail.lu
//
//  Created by Camptocamp on 01.07.20.
//  Copyright © 2020 Camptocamp. All rights reserved.
//

import Foundation
import Telegraph

public class HTTPContentTypeHandler: HTTPRequestHandler {
    public func respond(to request: HTTPRequest, nextHandler: HTTPRequest.Handler) throws -> HTTPResponse? {
        let response = try nextHandler(request)
        
        // Add access control header for GET requests
        if request.method == .GET {
            let split = request.uri.path.split(separator: ".")
            let ext = split[split.count - 1]
            var contentType = ""
            switch ext {
            case "json":
                contentType = "application/json"
                // This will rewrite style.json and other json files with the IP address of this server.
                var str = String(data: response!.body, encoding: .utf8)!
                str = str.replacingOccurrences(of: "https://vectortiles.geoportail.lu:", with: "http://localhost:8765")
                let listening = "https://127.0.0.1:8765/" // change here to test from outside (and enable listening on 0.0.0.0):
                str = str.replacingOccurrences(of: "http://localhost:8765/", with: listening)
                let content = str.data(using: .utf8)!
                response!.body = content
                break
            case "pbf":
                contentType = "application/x-protobuf"
                break
            case "html":
                contentType = "text/html; charset=utf-8"
                break
            default:
                contentType = "text/plain"
            }
            
            response?.headers.contentType = contentType
        }
        
        return response
    }
}
