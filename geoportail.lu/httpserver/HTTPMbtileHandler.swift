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
        
        let splitted = request.uri.path.components(separatedBy: "/")
        print(splitted)
        
        me: if (splitted.count == 6
            && splitted[1] == "data"
            && isSafeString(splitted[2])
            && (Int(splitted[3]) != nil)
            && (Int(splitted[4]) != nil)
            && splitted[5].hasSuffix(".pbf")) {
            let tileset = splitted[2]
            let zString = splitted[3]
            let xString = splitted[4]
            let yString = splitted[5].components(separatedBy: ".")[0]
            let z = Int(zString)!
            let x = Int(xString)!
            var y = Int(yString)!
            // https://github.com/mapbox/mbtiles-spec/blob/master/1.3/spec.md#content-1
            y = Int(pow(2.0, Double(z))) - 1 - y
            let source = MbtilesSource(forTileset: tileset)
            let data = source.getTile(x: x, y: y, z: z)
            if (data != nil) {
                let response = HTTPResponse(body: data!)
                response.headers.contentEncoding = "gzip"
                response.headers.contentType = "application/x-protobuf"
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
