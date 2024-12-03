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
        print("getItem", key)
        var value: String?
        ((try? dbQueue?.read { db in
            value = try String.fetchOne(db, sql: "SELECT value FROM offline WHERE key = ?", arguments: [key])
        }) as ()??)
        print("value: ", value ?? "")
        return value
    }
    
    func setItem(key: String, base64: String, action: Action42) {
        print("setItem: ", key, base64)
        ((try? dbQueue?.write { db in
            
            try db.execute(
                sql: "INSERT INTO offline (key, value) VALUES (?, ?)",
                arguments: [key, base64])
        }) as ()??)
    }
    
    func removeItem(key: String, action: Action42) {
        print("remove item: ", key)
        ((try? dbQueue?.write { db in
            try db.execute(sql: "DELETE FROM offline WHERE key = ?", arguments: [key])
        }) as ()??)
    }
    
    func clear(action: Action42) {
        print("clearing")
        ((try? dbQueue?.write { db in
            try db.execute(sql: "DELETE FROM offline")
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
