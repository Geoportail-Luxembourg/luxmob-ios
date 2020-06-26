//
//  MbtilesSource.swift
//  geoportail.lu
//
//  Created by Camptocamp on 04.06.20.
//  Copyright © 2020 Camptocamp. All rights reserved.
//

import GRDB
import Foundation


class MbtilesSource {
    var dbQueue: DatabaseQueue? = nil

    init(forTileset tileset: String) {
        let fileUrl = Bundle.main.url(forResource: tileset, withExtension: "mbtiles", subdirectory: "offline")
        do {
            if try fileUrl!.checkResourceIsReachable() {
                print("tileset", fileUrl!.path, "found")
            } else {
                print("tileset", fileUrl!.path, "not found")
            }
        } catch{
            print("error looking for tileset", tileset)
        }
        var config = Configuration()
        config.trace = { print($0) }
        try? dbQueue = DatabaseQueue(path: fileUrl!.path, configuration: config)
    }

    func getTile(x: Int, y: Int, z: Int) -> Data? {
        var value: Data?
        ((try? dbQueue?.read { db in
            value = try Data.fetchOne(db,
              "SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?",
              arguments: [z, x, y])
        }) as ()??)
        return value
    }
}
