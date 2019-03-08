//
//  ScriptMessageHandler.swift
//  LuxMob
//
//  Created by Camptocamp on 15.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import Foundation
import WebKit

typealias Action = [String: Any]


struct Response: Codable {
    var id: Int
    var command: String
    var args: [String?]
    var msg: String?
}

class SynchronizedStringStore {
    private var strings: [String] = []
    private var mutex = pthread_mutex_t()
    
    init() {
        pthread_mutex_init(&mutex, nil)
    }

    func removeFirst() -> String {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        return strings.removeFirst()
    }

    func append(_ str: String) {
        pthread_mutex_lock(&mutex)
        defer {
            pthread_mutex_unlock(&mutex)
        }
        strings.append(str)
    }
}

class ScriptMessageHandler: NSObject, WKScriptMessageHandler {

    private let encoder = JSONEncoder()
    private var webview: WKWebView
    private var backend: IBackend?
    private let backendQueue = DispatchQueue(label: "myBackendQueue", qos: .userInitiated, attributes: [])
    private let semaphore = DispatchSemaphore(value: 0)
    private var backendThread: Thread?
    private var webviewMesages = SynchronizedStringStore()

    init(webview: WKWebView) {
        self.webview = webview
        super.init()
        backendThread = Thread { [unowned semaphore, unowned self] in
            while true {
                semaphore.wait()
                if Thread.current.isCancelled {
                    return
                }
                let msg = self.webviewMesages.removeFirst()
                self.handleMessage(msg: msg)
            }
        }
        backendThread!.start()
    }
    
    deinit {
        backendThread!.cancel()
        semaphore.signal()
    }

    private func printThread() {
        print(Thread.current)
    }

    private func getItem(_ action: Action) {
        let args = action["args"] as! [String]
        self.printThread()
        let value = self.backend!.getItem(key: args[0], action: action)
        DispatchQueue.main.async {
            self.postResponseToWebview(args: [value], action)
        }
    }

    func setItem(_ action: Action42) {
        let args = action["args"] as! [String]
        let key = args[0]
        let value = args[1]
        self.printThread()
        self.backend!.setItem(key: key, base64: value, action: action)
        DispatchQueue.main.async {
            self.postResponseToWebview(args: [], action)
        }
    }
    
    func removeItem(_ action: Action42) {
        let args = action["args"] as! [String]
        self.printThread()
        self.backend!.removeItem(key: args[0], action: action)
        DispatchQueue.main.async {
            self.postResponseToWebview(args: [], action)
        }
    }
    
    func clear(_ action: Action42) {
        self.printThread()
        self.backend!.clear(action: action)
        DispatchQueue.main.async {
            self.postResponseToWebview(args: [], action)
        }
    }
    
    func config(_ action: Action42) {
        self.printThread()
        self.backend = LocalForageSqliteBackend()
        self.backend!.config(action: action)
        DispatchQueue.main.async {
            self.postResponseToWebview(args: [], action)
        }
}

    private func postResponseToWebview(args: [String?], _ action: Action) {
        let id = action["id"] as! Int
        let command = "response"
        let response: Response = Response(id: id, command: command, args: args, msg: "")
        let data = try! encoder.encode(response)
        postDataToWebview(data)
    }
    
    private func postErrorToWebview(msg: String, _ action: Action) {
        let id = action["id"] as! Int
        let response: Response = Response(id: id, command: "error", args: [], msg: msg)
        let data = try! encoder.encode(response)
        postDataToWebview(data)
    }
    
    private func postDataToWebview(_ data: Data) {
        let textString = String(data: data, encoding: .utf8)
        // JSON serializer is used to escape the string
        let escapedData = try! JSONSerialization.data(withJSONObject: [textString] as Any)
        let escapedStringArray = String(data: escapedData, encoding: .utf8)!
        let start = escapedStringArray.index(escapedStringArray.startIndex, offsetBy: 2)
        let end = escapedStringArray.index(escapedStringArray.endIndex, offsetBy: -2)
        let substr = escapedStringArray[start..<end]
        let js = "window.iosWrapper.receiveFromIos('\(substr)');"
        webview.evaluateJavaScript(js)
    }
    
    private func handleMessage(msg: String) {
        let data = msg.data(using: .utf8)!
        let json = try! JSONSerialization.jsonObject(with: data) as! [String : Any]
        let plugin = json["plugin"] as! String
        if plugin != "localforage" {
            return
        }
        
        let command = json["command"] as! String
        switch command {
        case "getItem":
            getItem(json)
        case "setItem":
            setItem(json)
        case "removeItem":
            removeItem(json)
        case "clear":
            clear(json)
        case "config":
            config(json)
        default:
            postErrorToWebview(msg: "Unhandled command \(command)", json)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "ios" {
            let msg = message.body as! String
            webviewMesages.append(msg)
            semaphore.signal()
        }
    }
}
