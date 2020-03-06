//
//  IBackend.swift
//  geoportail.lu
//
//  Created by Camptocamp on 18.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

typealias Action42 = [String : Any]

protocol IBackend {
    func getItem(key: String, action: Action42) -> String?
    func setItem(key: String, base64: String, action: Action42)
    func removeItem(key: String, action: Action42)
    func clear(action: Action42)
    func config(action: Action42)
}
