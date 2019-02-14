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

    var webView : WKWebView? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        let url = URL(string: "https://offline-demo.geoportail.lu")
        webView!.load(URLRequest(url: url!))
        webView!.allowsBackForwardNavigationGestures = true
    }

    override func loadView() {
        webView = WebKit.WKWebView()
        webView!.navigationDelegate = self
        view = webView
    }
}
