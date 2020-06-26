//
//  ViewController.swift
//  geoportail.lu
//
//  Created by Camptocamp on 14.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import UIKit
import WebKit
import Telegraph


class ViewController: UIViewController, WKNavigationDelegate {
    
    var server : EmbeddedServer?
    var webView : WKWebView?
    // For production
    // var websiteURL : String = "https://map.geoportail.lu/?localforage=ios&ipv6=true&applogin=yes"
    // For testing with a server on a local machine
    // var websiteURL : String = "http://192.168.0.10:8080/?localforage=ios&applogin=yes&embeddedserver=127.0.0.1:8765"
    // For testing the c2cnextprod branch
    var websiteURL : String = "https://migration.geoportail.lu/?localforage=ios&applogin=yes&embeddedserver=127.0.0.1:8765&embeddedserverprotocol=https"
    //var websiteURL = "http://localhost:8765/index.html"
    //var websiteURL : String = "https://192.168.0.10:9876"
    
    
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
        
        server = EmbeddedServer(port:8765)
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
    
    // This will override the SSL certificate verification
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let ps = challenge.protectionSpace
        if (ps.authenticationMethod == NSURLAuthenticationMethodServerTrust &&
            (ps.host == "192.168.0.10" || ps.host == "127.0.0.1" || ps.host == "localhost")) {
            print("Accepting the server certificate for", ps.host, ps.protocol!)
            let cred = URLCredential.init(trust: ps.serverTrust!)
            completionHandler(.useCredential, cred)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
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
