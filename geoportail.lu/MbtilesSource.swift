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
    let dbQueue: DatabaseQueue

    init(forTileset tileset: String) {
        let fileUrl = Bundle.main.url(forResource: tileset, withExtension: "mbtiles", subdirectory: "offline/mbtiles")
        dbQueue = try! DatabaseQueue(path: fileUrl!.path, configuration: Configuration())
    }
    static func exists(tileset: String) -> Bool {
        if (Bundle.main.path(forResource: tileset, ofType: "mbtiles", inDirectory: "offline/mbtiles") != nil) {
           return true
        }
        return false
    }
    func getTile(x: Int, y: Int, z: Int) -> Data? {
        var value: Data?
        ((try? dbQueue.read { db in
            value = try Data.fetchOne(db,
                                      sql: "SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?",
              arguments: [z, x, y])
        }) as ()??)
        return value
    }
}
