import SwiftUI
import WebKit
import UIKit

struct WebView: UIViewRepresentable {
    let urlString: String
    @Binding var showScanner: Bool
    @Binding var scanResult: ScanCallbackResult?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        
        // 支持网页内媒体播放（麦克风、摄像头）
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "invokeGetMachineid")
        userContentController.add(context.coordinator, name: "invokeStartScanning")
        userContentController.add(context.coordinator, name: "invokeStopScanning")
        webConfiguration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        // 禁用 WebView 自身的滚动和反弹
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        uiView.load(request)
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
            super.init()
            
            // 监听扫码结果通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScanResultNotification(_:)),
                name: .scanResult,
                object: nil
            )
        }
        
        @objc private func handleScanResultNotification(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let key = userInfo["key"] as? String,
                  let value = userInfo["value"] as? String else { return }
            print("📱 [Native] 收到扫码结果通知: key=\(key), value=\(value)")
            callbackScanResult(key: key, value: value)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("📱 [Native] 收到 JS 消息: \(message.name), body: \(message.body)")
            
            switch message.name {
            case "invokeGetMachineid":
                handleGetMachineid()
            case "invokeStartScanning":
                handleStartScanning()
            case "invokeStopScanning":
                handleStopScanning()
            default:
                break
            }
        }
        
        // MARK: - 获取设备ID
        private func handleGetMachineid() {
            print("📱 [Native] 前端调用了 getMachineid 方法")
            let machineId = getMachineId()
            print("📱 [Native] 获取到的设备 ID: \(machineId)")
            let jsCode = "window.setMachineid('\(machineId)')"
            print("📱 [Native] 回调 JS: \(jsCode)")
            webView?.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("📱 [Native] 回调 JS 失败: \(error.localizedDescription)")
                } else {
                    print("📱 [Native] 回调 JS 成功")
                }
            }
        }
        
        private func getMachineId() -> String {
            let key = "MACHINE_ID"
            
            if let savedId = KeychainManager.load(key: key) {
                print("📱 [Native] 从 Keychain 获取设备 ID: \(savedId)")
                return savedId
            }
            
            let newId: String
            if let uuid = UIDevice.current.identifierForVendor?.uuidString {
                newId = uuid.replacingOccurrences(of: "-", with: "")
            } else {
                newId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            
            let success = KeychainManager.save(key: key, value: newId)
            if success {
                print("📱 [Native] 设备 ID 已保存到 Keychain: \(newId)")
            } else {
                print("📱 [Native] 设备 ID 保存到 Keychain 失败")
            }
            
            return newId
        }
        
        // MARK: - 扫码
        private func handleStartScanning() {
            print("📱 [Native] 前端调用了 startScan 方法")
            DispatchQueue.main.async {
                self.parent.showScanner = true
            }
        }
        
        private func handleStopScanning() {
            print("📱 [Native] 前端调用了 stopScan 方法")
            DispatchQueue.main.async {
                self.parent.showScanner = false
            }
        }
        
        func callbackScanResult(key: String, value: String) {
            let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")
            let jsCode = "window.setScanResult({key:'\(key)',value:'\(escapedValue)'})"
            print("📱 [Native] 回调扫码结果 JS: \(jsCode)")
            webView?.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("📱 [Native] 回调扫码结果失败: \(error.localizedDescription)")
                } else {
                    print("📱 [Native] 回调扫码结果成功")
                }
            }
        }
        
        // MARK: - WKUIDelegate: 媒体权限自动允许（只弹系统级一次，网页级不再弹窗）
        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            print("📱 [Native] 网页请求媒体权限: type=\(type.rawValue), origin=\(origin.host ?? "")")
            // 直接允许，由系统级权限控制（系统级只弹一次）
            decisionHandler(.grant)
        }
        
        // MARK: - 页面加载完成，注入JS API
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("📱 [Native] 页面加载完成，准备注入 commonApi / scanApi")
            let jsCode = """
            window.commonApi = {
                getMachineid: function() {
                    console.log('[JS] 调用 Native getMachineid');
                    window.webkit.messageHandlers.invokeGetMachineid.postMessage({});
                }
            };
            window.scanApi = {
                startScan: function() {
                    console.log('[JS] 调用 Native startScan');
                    window.webkit.messageHandlers.invokeStartScanning.postMessage({});
                },
                stopScan: function() {
                    console.log('[JS] 调用 Native stopScan');
                    window.webkit.messageHandlers.invokeStopScanning.postMessage({});
                }
            };
            console.log('[JS] commonApi / scanApi 已注入');
            """
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("📱 [Native] 注入 API 失败: \(error.localizedDescription)")
                } else {
                    print("📱 [Native] commonApi / scanApi 注入成功")
                }
            }
        }
    }
}

enum ScanCallbackResult {
    case suc(String)
    case close
    case error(String)
}
