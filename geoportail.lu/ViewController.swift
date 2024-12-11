//
//  ViewController.swift
//  geoportail.lu
//
//  Created by Camptocamp on 14.02.19.
//  Copyright © 2019 Camptocamp. All rights reserved.
//

import UIKit
@preconcurrency import WebKit
import Telegraph


class ViewController: UIViewController, WKNavigationDelegate {
    
    let server = EmbeddedServer(port:8765)
    var webView : WKWebView!
    #if DEBUG
    // For testing the migration branch
    var websiteURL : String = "https://migration.geoportail.lu/?localforage=ios&applogin=yes&embeddedserver=127.0.0.1:8765&embeddedserverprotocol=https&version=3"
    //let websiteURL : String = "https://map.geoportail.lu/?localforage=ios&ipv6=true&applogin=yes&embeddedserver=127.0.0.1:8765/static&embeddedserverprotocol=https&version=3"
    #else
    // For production
    let websiteURL : String = "https://map.geoportail.lu/?localforage=ios&ipv6=true&applogin=yes&embeddedserver=127.0.0.1:8765&embeddedserverprotocol=https&version=3"

    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        let webView = self.webView
        let url = URL(string: self.websiteURL) //new map link
        webView!.load(URLRequest(url: url!))
        webView!.allowsBackForwardNavigationGestures = true
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
    }

    override func loadView() {
        super.loadView()
        let controller = WKUserContentController()
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        
        webView = WebKit.WKWebView(frame: .zero, configuration: config)
        controller.add(ScriptMessageHandler(webview: webView!), name: "ios")
        webView.navigationDelegate = self
        //webView.isInspectable = true // Enable to use safari inspector
        view = webView
    }
    
    // This will override the SSL certificate verification on localhost and some local test server
    // This is necessary since we use a self-signed certificate for the embedded HTTP server
    // Note that we completly bypass any verification. We could instead do custom validation of the certificate
    // by using our CA but it would not bring any additional security.
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let ps = challenge.protectionSpace
        if (ps.authenticationMethod == NSURLAuthenticationMethodServerTrust &&
            (ps.host == "192.168.0.10" || ps.host == "127.0.0.1" || ps.host == "localhost")) {
            let cred = URLCredential.init(trust: ps.serverTrust!)
            completionHandler(.useCredential, cred)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated || (navigationAction.request.url?.absoluteString.contains("printproxy"))! {
            redirectToBrowser(navigationAction: navigationAction, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func redirectToBrowser(navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let newURL = navigationAction.request.url,
            let host = newURL.host , !host.hasPrefix(websiteURL) &&
            UIApplication.shared.canOpenURL(newURL) {
            decisionHandler(.cancel)
            UIApplication.shared.open(newURL, options: [:], completionHandler: nil)
        } else {
            decisionHandler(.allow)
        }
    }
}
