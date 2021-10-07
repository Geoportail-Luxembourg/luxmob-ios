//
//  LocalforageSQliteBackend.swift
//  geoportail.lu
//
//  Created by Camptocamp on 18.02.20.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import GRDB
import Foundation

class LocalForageSqliteBackend: IBackend {
    
    var dbQueue: DatabaseQueue? = nil

    func getItem(key: String, action: Action42) -> String? {
        var value: String?
        ((try? dbQueue?.read { db in
            value = try String.fetchOne(db, sql: "SELECT value FROM Offline WHERE key = ?", arguments: [key])
        }) as ()??)
        return value
    }
    
    func setItem(key: String, base64: String, action: Action42) {
        ((try? dbQueue?.write { db in
            try db.execute(
                sql: "INSERT INTO Offline (key, value) VALUES (?, ?)",
                arguments: [key, base64])
        }) as ()??)
    }
    
    func removeItem(key: String, action: Action42) {
        ((try? dbQueue?.write { db in
            try db.execute(sql: "DELETE FROM Offline WHERE key = ?", arguments: [key])
        }) as ()??)
    }
    
    func clear(action: Action42) {
        ((try? dbQueue?.write { db in
            try db.execute(sql: "DELETE FROM Offline")
        }) as ()??)
    }
    
    func config(action: Action42) {
        var fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        fileUrl.appendPathComponent("my_super_lux.db")
        try? dbQueue = DatabaseQueue(path: fileUrl.path)
        ((try? dbQueue?.write { db in
            try db.execute(sql: "CREATE TABLE offline (key TEXT PRIMARY KEY, value TEXT)")
        }) as ()??)
    }
}
