//
//  HTTPMbtileHandler.swift
//  geoportail.lu
//
//  Created by Camptocamp on 01.07.20.
//  Copyright © 2020 Camptocamp. All rights reserved.
//

import Foundation
import Telegraph


public class HTTPMbtileHandler: HTTPRequestHandler {
    public func respond(to request: HTTPRequest, nextHandler: HTTPRequest.Handler) throws -> HTTPResponse? {
        
        var queryParams: [String: String] = [:]
        for qItem in request.uri.queryItems ?? [] {
            queryParams[qItem.name] = qItem.value
        }
        let tileset = queryParams["layer"] ?? "omt-geoportail"
        let fileFormat = queryParams["format"] ?? "pbf"
        let nf = NumberFormatter()
        let xParam = queryParams["x"]
        let yParam = queryParams["y"]
        let zParam = queryParams["z"]
 
    me: if xParam != nil && yParam != nil && zParam != nil {
            // https://github.com/mapbox/mbtiles-spec/blob/master/1.3/spec.md#content-1
            let z: Int? = nf.number(from: zParam!)?.intValue
            let x: Int? = nf.number(from: xParam!)?.intValue
            var y: Int? = nf.number(from: yParam!)?.intValue
            y = Int(pow(2.0, Double(z!))) - 1 - y!
            let source = MbtilesSource(forTileset: tileset)
            let data = source.getTile(x: x!, y: y!, z: z!)
            if (data != nil) {
                let response = HTTPResponse(body: data!)
                if fileFormat == "pbf" {
                    response.headers.contentEncoding = "gzip"
                    response.headers.contentType = "application/x-protobuf"
                } else if fileFormat == "png" {
                    response.headers.contentType = "image/png"
                }
                response.headers.accessControlAllowOrigin = "*"
                return response
            } else {
                let response = HTTPResponse(.notFound)
                response.headers.accessControlAllowOrigin = "*"
                return response
            }
        }
        let response = try nextHandler(request)
        
        return response
    }
}

private func isSafeString(_ str: String) -> Bool {
    let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_"
    let characterSet = CharacterSet(charactersIn: allowed)
    guard str.rangeOfCharacter(from: characterSet.inverted) == nil else {
        return false
    }
    return true
}
