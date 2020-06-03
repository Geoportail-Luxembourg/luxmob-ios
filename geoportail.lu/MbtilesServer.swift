import Foundation



class MbtilesServer: NSObject {
    
    // MARK: Properties
    
    static let shared = MbtilesServer()
    private var webServer: GCDWebServer? = nil
    
    // MARK: Functions
    
    func start(port: UInt) {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { [weak self] in
                self?.start(port: port)
            }
            return
        }
        
        if webServer == nil {
            webServer = GCDWebServer()
        }
        guard !webServer!.isRunning else {
            return
        }
        GCDWebServer.setLogLevel(3)
        webServer?.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: { [weak self] (request: GCDWebServerRequest) -> GCDWebServerResponse? in
            return self?.handleGetRequest(request)
        })
        webServer?.start(withPort: port, bonjourName: nil)
    }
    
    func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { [weak self] in
                self?.stop()
            }
            return
        }
        
        webServer?.stop()
        webServer?.removeAllHandlers()
    }
    
    private func handleGetRequest(_ request: GCDWebServerRequest) -> GCDWebServerResponse? {
        if (request.path as NSString).pathExtension == "mbtiles"
            // ,
//            let query = request.query,
//            let xString = query["x"],
//            let yString = query["y"],
//            let zString = query["z"],
//            let x = Int(xString),
//            let y = Int(yString),
//            let z = Int(zString)
        {
            let data = "coco".data(using: .utf8)!
            return GCDWebServerDataResponse(data: data, contentType: "")
        } else {
            return GCDWebServerResponse(statusCode: 404)
        }
    }
}
