//
//  ViewController.swift
//  LuxMob
//
//  Created by Camptocamp on 14.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import UIKit
import WebKit


class ViewController: UIViewController, WKNavigationDelegate {

    var webView : WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        // let url = URL(string: "http://wrk29.wrk.lsn.camptocamp.com:5000?localforage=ios&localhost")
        let url = URL(string: "https://map.geoportail.lu/?localforage=ios&ipv6=true&applogin=yes") //new map link
        // let url = URL(string: "https://offline-demo.geoportail.lu") // 100% functional, without native backend
        webView!.load(URLRequest(url: url!))
        webView!.allowsBackForwardNavigationGestures = true
    }

    override func loadView() {
        super.loadView()
        let controller = WKUserContentController()
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        
        webView = WebKit.WKWebView(frame: .zero, configuration: config)
        controller.add(ScriptMessageHandler(webview: webView!), name: "ios")
        webView!.navigationDelegate = self
        view = webView
    }
}
