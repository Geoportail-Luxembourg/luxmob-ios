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
        let offline = Bundle.main.url(forResource: "offline", withExtension: nil)!
        server.serveDirectory(offline, "/")

        try! server.start(port: port)
    }
}
