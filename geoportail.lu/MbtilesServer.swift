import Foundation


class MbtilesServer: NSObject {
    
    static let shared = MbtilesServer()
    private var webServer: GCDWebServer? = nil

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
        do {
            try webServer?.start(options: [
                // comment following line to listen on public interface
                GCDWebServerOption_BindToLocalhost: true,
                GCDWebServerOption_Port: port
            ])
            print("server URL", webServer?.serverURL as Any)
        } catch {
            print("failed to start embedded web server")
        }
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
        // Request URL:https://vectortiles.geoportail.lu/data/omt-geoportail-lu/9/264/174.pbf
        if (request.path as NSString).pathExtension == "pbf" {
            let splitted = request.path.components(separatedBy: "/")
            print(splitted)
            let zString = splitted[3]
            let xString = splitted[4]
            let yString = splitted[5].components(separatedBy: ".")[0]
            print(zString, xString, yString)
            let z = Int(zString)!
            let x = Int(xString)!
            var y = Int(yString)!
            // https://github.com/mapbox/mbtiles-spec/blob/master/1.3/spec.md#content-1
            y = Int(pow(2.0, Double(z))) - 1 - y
            print(z, x, y)
            let source = MbtilesSource()
            let data = source.getTile(x: x, y: y, z: z)
            if (data != nil) {
                let response = GCDWebServerDataResponse(data: data!, contentType: "application/x-protobuf")
                response.setValue("*", forAdditionalHeader: "access-control-allow-origin")
                response.setValue("gzip", forAdditionalHeader: "content-encoding")
                return response
            } else {
                let response = GCDWebServerResponse(statusCode: 404)
                response.setValue("*", forAdditionalHeader: "access-control-allow-origin")
                return response
            }
        } else {
            let response = GCDWebServerResponse(statusCode: 400)
            response.setValue("*", forAdditionalHeader: "access-control-allow-origin")
            return response
        }
    }
}
