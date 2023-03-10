//
//  mbTilesTests.swift
//  geoportail.luTests
//
//  Created by camptocamp on 10/03/2023.
//  Copyright © 2023 Camptocamp. All rights reserved.
//

import XCTest
import geoportail_lu

class mbTileServerTests: XCTestCase {
    var mcm: MbTilesCacheManager?
    var url = "https://localhost"
    var port = 0

    override func setUpWithError() throws {
        mcm = MbTilesCacheManager(metaUrl: "https://vectortiles-sync.geoportail.lu/metadata/resources.meta")
        try! mcm?.downloadMeta()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCheck() throws {
        let resStatus = mcm?.getStatus(resName: "resources")
        XCTAssert(resStatus == .UNKNOWN)
    }

    func testUpdate() throws {
        let allStatus = try mcm?.getLayersStatus()
        let update = mcm?.updateRes(resName: "resources")
        XCTAssert(update ?? false)
        var resStatus = mcm?.getStatus(resName: "resources")
        while resStatus == .IN_PROGRESS {
            sleep(5)
            resStatus = mcm?.getStatus(resName: "resources")
        }
        resStatus = mcm?.getStatus(resName: "resources")
    }
}
