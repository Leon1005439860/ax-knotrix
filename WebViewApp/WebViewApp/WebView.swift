import SwiftUI
import WebKit
import UIKit

struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "invokeGetMachineid")
        webConfiguration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        uiView.load(request)
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            print("📱 [Native] 收到 JS 消息: \(message.name), body: \(message.body)")
            if message.name == "invokeGetMachineid" {
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
        }
        
        private func getMachineId() -> String {
            if let uuid = UIDevice.current.identifierForVendor?.uuidString {
                return uuid
            }
            return UUID().uuidString
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("📱 [Native] 页面加载完成，准备注入 commonApi")
            let jsCode = """
            window.commonApi = {
                getMachineid: function() {
                    console.log('[JS] 调用 Native getMachineid');
                    window.webkit.messageHandlers.invokeGetMachineid.postMessage({});
                }
            };
            console.log('[JS] commonApi 已注入');
            """
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("📱 [Native] 注入 commonApi 失败: \(error.localizedDescription)")
                } else {
                    print("📱 [Native] commonApi 注入成功")
                }
            }
        }
    }
}
