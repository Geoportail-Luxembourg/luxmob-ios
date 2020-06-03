//
//  ViewController.swift
//  geoportail.lu
//
//  Created by Camptocamp on 14.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {

    var webView : WKWebView?
    var websiteURL : String = "https://map.geoportail.lu/?localforage=ios&ipv6=true&applogin=yes"

    override func viewDidLoad() {
        super.viewDidLoad()
        // let url = URL(string: "http://wrk29.wrk.lsn.camptocamp.com:5000?localforage=ios&localhost")
        let url = URL(string: websiteURL) //new map link
        // let url = URL(string: "https://offline-demo.geoportail.lu") // 100% functional, without native backend
        webView!.load(URLRequest(url: url!))
        webView!.allowsBackForwardNavigationGestures = true
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        } else {
            // Fallback on earlier versions
        }
        // FIXME: only listen on localhost!
        MbtilesServer.shared.start(port: 8765)
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
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//        print(navigationAction.request.url)
        if navigationAction.navigationType == .linkActivated || (navigationAction.request.url?.absoluteString.contains("printproxy"))! {
            redirectToBrowser(navigationAction: navigationAction, decisionHandler: decisionHandler)
        } else {
            print("not a user click")
            decisionHandler(.allow)
        }
    }
    
    func redirectToBrowser(navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let newURL = navigationAction.request.url,
            let host = newURL.host , !host.hasPrefix(websiteURL) &&
            UIApplication.shared.canOpenURL(newURL) {
            print(newURL)
            print("Redirected to browser. No need to open it locally")
            decisionHandler(.cancel)
            UIApplication.shared.open(newURL, options: [:], completionHandler: nil)
        } else {
            print("Open it locally")
            decisionHandler(.allow)
        }
    }
}
