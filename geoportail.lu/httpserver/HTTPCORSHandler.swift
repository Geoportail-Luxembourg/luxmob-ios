//
//  HTTPCORSHandler.swift
//  geoportail.lu
//
//  Created by Camptocamp on 01.07.20.
//  Copyright © 2020 Camptocamp. All rights reserved.
//

import Foundation
import Telegraph

public class HTTPCORSHandler: HTTPRequestHandler {
    public func respond(to request: HTTPRequest, nextHandler: HTTPRequest.Handler) throws -> HTTPResponse? {
        let response = try nextHandler(request)
        if (request.headers.origin != nil) {
            response?.headers.accessControlAllowOrigin = "*"
        }
        return response
    }
}
