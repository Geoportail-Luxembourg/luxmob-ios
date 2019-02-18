//
//  ScriptMessageHandler.swift
//  LuxMob
//
//  Created by Camptocamp on 15.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import Foundation
import WebKit

struct Action: Codable {
    var id: Float
    var plugin: String
    var command: String?
    //var args: Array<String>?
}

struct Response: Codable {
    var id: Float
    var command: String
    //var args: Array<String>?
    var msg: String?
}

class ScriptMessageHandler: NSObject, WKScriptMessageHandler {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var webview: WKWebView

    init(webview: WKWebView) {
        self.webview = webview
        super.init()
    }
    
    private func getItem(_ action: Action) {
        
    }

    private func postErrorToWebview(msg: String, _ action: Action) {
        let response: Response = Response(id: action.id, command: "error", msg: msg)
        postResponseToWebview(response)
    }
    
    private func postResponseToWebview(_ response: Response) {
        let text = try? encoder.encode(response)
        let escaped = text // FIXME escape
        let js = "window.iosWrapper.receiveFromIos(\(escaped!));"
        print("Posting response \(js)")
        webview.evaluateJavaScript(js)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "ios" {
            let bodyString = message.body as! String
            let data = bodyString.data(using: .utf8)!
            let action = try? decoder.decode(Action.self, from: data)
            if action == nil || action!.plugin != "localforage" {
                return
            }
                
            let command = action!.command!
            switch command {
                case "getItem":
                    getItem(action!)
                default:
                    postErrorToWebview(msg: "Unhandled command \(command)", action!)
                }
            }
        }
    }
}
