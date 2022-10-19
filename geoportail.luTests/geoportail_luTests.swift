//
//  geoportail_luTests.swift
//  geoportail.luTests
//
//  Created by camptocamp on 24/11/2021.
//  Copyright © 2021 Camptocamp. All rights reserved.
//

import XCTest
import geoportail_lu

class geoportail_luTests: XCTestCase {
    var server: EmbeddedServer?
    var url = "https://localhost"
    var port = 0
    
    override func setUpWithError() throws {
        port = Int.random(in: 1024..<65535)
        server = EmbeddedServer(port: port)
        url = "\(url):\(port)"
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPing() throws {
        let url = URL(string: "\(url)/ping")

        let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
            XCTAssertEqual(String(data: data!, encoding: .utf8), "pong")
            let httpStatus = response as? HTTPURLResponse
            XCTAssertEqual(httpStatus!.statusCode, 200)
        }
        task.resume()
    }
    
    func testCheckUpdate() throws {
        let url = URL(string: "\(url)/check")
        let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
            XCTAssertEqual(String(data: data!, encoding: .utf8), "pong")
            let httpStatus = response as? HTTPURLResponse
            XCTAssertEqual(httpStatus!.statusCode, 200)
        }
        task.resume()
    }
    
    func testAskUpdate() throws {
        let url = URL(string: "\(url)/map/doesNotExist")
        let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
            XCTAssertEqual(String(data: data!, encoding: .utf8), "pong")
            let httpStatus = response as? HTTPURLResponse
            XCTAssertEqual(httpStatus!.statusCode, 200)
        }
        task.resume()
    }
}
