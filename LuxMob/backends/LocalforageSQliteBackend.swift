//
//  LocalforageSQliteBackend.swift
//  LuxMob
//
//  Created by Camptocamp on 18.02.20.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import Foundation

class LocalForageSqliteBackend: IBackend {
    
    var db: SQLiteDatabase? = nil

    func getItem(key: String, action: Action42) -> String? {
        return db!.getItem(key: key)
    }
    
    func setItem(key: String, base64: String, action: Action42) {
        // FIXME: what to do in case of
        try? db!.setItem(key: key, value: base64)
    }
    
    func removeItem(key: String, action: Action42) {
        db!.removeItem(key: key)
    }
    
    func clear(action: Action42) {
        db!.clear()
    }
    
    func config(action: Action42) {
        var fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        fileUrl.appendPathComponent("my_super_lux.db")
        try? db = SQLiteDatabase.open(path: fileUrl.path)
    }
}
