//
//  LocalforageMemoryBackend.swift
//  geoportail.lu
//
//  Created by Camptocamp on 18.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import Foundation
class LocalForageMemoryBackend: IBackend {
    
    var map = [String: String]()

    func getItem(key: String, action: Action42) -> String? {
        print("memory getitem", key)
        return map[key]
    }
    
    func setItem(key: String, base64: String, action: Action42) {
        print("memory setItem", key, base64)
        map[key] = base64
    }
    
    func removeItem(key: String, action: Action42) {
        print("memory removeItem", key)
        map.removeValue(forKey: key)
    }
    
    func clear(action: Action42) {
        print("memory clearing")
        map.removeAll()
    }
    
    func config(action: Action42) {
        // do nothing
    }
    
    
}
