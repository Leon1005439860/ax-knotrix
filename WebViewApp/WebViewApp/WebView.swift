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
        userContentController.add(context.coordinator, name: "invokeTokenMissing")
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
        
        private var tokenRetryCount = 0
        private let maxTokenRetries = 5
        private let tokenRetryInterval: TimeInterval = 0.2
        private var hasInjectedCommonApi = false
        
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
            case "invokeTokenMissing":
                handleTokenMissing()
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
        
        // MARK: - Token 失效（退出登录）
        private func handleTokenMissing() {
            print("📱 [Native] 前端调用了 tokenMissing，清除本地 token 并返回注册页")
            KeychainManager.delete(key: "TOKEN")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .tokenMissing, object: nil)
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
            print("📱 [Native] 页面加载完成，准备注入 token / commonApi / scanApi")
            tokenRetryCount = 0
            hasInjectedCommonApi = false
            injectTokenAndAPIs()
        }
        
        private func injectTokenAndAPIs() {
            guard let webView = webView else { return }
            
            let token = KeychainManager.load(key: "TOKEN") ?? ""
            let escapedToken = token.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            
            if tokenRetryCount == 0 {
                print("📱 [Native] 当前 token: \(token.prefix(20))\(token.count > 20 ? "..." : "") (长度: \(token.count))")
            }
            
            let injectCommonApi = !hasInjectedCommonApi
            
            let jsCode = """
            (function() {
                var result = {
                    setNativeTokenExists: false,
                    setNativeTokenCalled: false,
                    commonApiInjected: false,
                    scanApiInjected: false,
                    error: null
                };
                try {
                    if (typeof setNativeToken === 'function') {
                        result.setNativeTokenExists = true;
                        setNativeToken('\\(escapedToken)');
                        result.setNativeTokenCalled = true;
                    } else {
                        result.setNativeTokenExists = false;
                    }
                    
                    if (\(injectCommonApi ? "true" : "false")) {
                        window.commonApi = {
                            getMachineid: function() {
                                window.webkit.messageHandlers.invokeGetMachineid.postMessage({});
                            }
                        };
                        result.commonApiInjected = true;
                        
                        window.scanApi = {
                            startScan: function() {
                                window.webkit.messageHandlers.invokeStartScanning.postMessage({});
                            },
                            stopScan: function() {
                                window.webkit.messageHandlers.invokeStopScanning.postMessage({});
                            }
                        };
                        result.scanApiInjected = true;
                    } else {
                        result.commonApiInjected = true;
                        result.scanApiInjected = true;
                    }
                } catch(e) {
                    result.error = e.message || String(e);
                }
                return JSON.stringify(result);
            })();
            """
            webView.evaluateJavaScript(jsCode) { [weak self] result, error in
                guard let self = self else { return }
                
                if injectCommonApi {
                    self.hasInjectedCommonApi = true
                }
                
                if let error = error {
                    print("📱 [Native] ❌ 第 \(self.tokenRetryCount + 1) 次注入失败: \(error.localizedDescription)")
                    return
                }
                
                guard let resultString = result as? String,
                      let data = resultString.data(using: .utf8),
                      let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }
                
                let tokenExists = dict["setNativeTokenExists"] as? Bool ?? false
                let tokenCalled = dict["setNativeTokenCalled"] as? Bool ?? false
                
                if self.tokenRetryCount == 0 {
                    print("📱 [Native] ─── JS 注入结果 (第 1 次) ───")
                    print("📱 [Native]   setNativeToken 存在: \(tokenExists ? "✅" : "❌")")
                    print("📱 [Native]   setNativeToken 已调用: \(tokenCalled ? "✅" : "❌")")
                    print("📱 [Native]   commonApi 注入: \(dict["commonApiInjected"] as? Bool ?? false ? "✅" : "❌")")
                    print("📱 [Native]   scanApi 注入:   \(dict["scanApiInjected"] as? Bool ?? false ? "✅" : "❌")")
                    if let err = dict["error"] as? String, !err.isEmpty {
                        print("📱 [Native]   JS 错误: \(err)")
                    }
                }
                
                if tokenCalled {
                    print("📱 [Native] ✅ setNativeToken 调用成功 (第 \(self.tokenRetryCount + 1) 次)")
                    return
                }
                
                if self.tokenRetryCount < self.maxTokenRetries {
                    self.tokenRetryCount += 1
                    print("📱 [Native] ⏳ setNativeToken 不存在，\(self.tokenRetryInterval)s 后重试 (第 \(self.tokenRetryCount)/\(self.maxTokenRetries) 次)...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.tokenRetryInterval) { [weak self] in
                        self?.injectTokenAndAPIs()
                    }
                } else {
                    print("📱 [Native] ❌ 已重试 \(self.maxTokenRetries) 次，setNativeToken 仍不存在，放弃")
                    print("📱 [Native] 💡 请确认前端页面是否定义了 window.setNativeToken 函数")
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
