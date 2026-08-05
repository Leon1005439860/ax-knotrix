import SwiftUI

struct ContentView: View {
    //private let urlString = "http://192.168.118.157:5173/llk-webapp"
    private let urlString = "https://sit-k-library.accentrix.com/llk-webapp/#/register"
    
    @State private var showScanner = false
    @State private var scanResult: ScanCallbackResult?
    
    var body: some View {
        WebView(urlString: urlString, showScanner: $showScanner, scanResult: $scanResult)
            .ignoresSafeArea()
            .onAppear {
                // 禁用 WebView 反弹效果，并允许 WKWebView 内部 JS 控制滚动
                // 锁死 App 整体滚动
                UIScrollView.appearance().isScrollEnabled = false
                UIScrollView.appearance().bounces = false
            }
            .sheet(isPresented: $showScanner) {
                ScannerView(
                    onResult: { value in
                        print("📱 [Native] 扫码成功: \(value)")
                        showScanner = false
                        // 通过通知发送扫码结果
                        NotificationCenter.default.post(
                            name: .scanResult,
                            object: nil,
                            userInfo: ["key": "suc", "value": value]
                        )
                    },
                    onClose: {
                        print("📱 [Native] 用户取消扫码")
                        showScanner = false
                        NotificationCenter.default.post(
                            name: .scanResult,
                            object: nil,
                            userInfo: ["key": "close", "value": ""]
                        )
                    },
                    onError: { errorMsg in
                        print("📱 [Native] 扫码错误: \(errorMsg)")
                        showScanner = false
                        NotificationCenter.default.post(
                            name: .scanResult,
                            object: nil,
                            userInfo: ["key": "error", "value": errorMsg]
                        )
                    }
                )
            }
    }
}

extension Notification.Name {
    static let scanResult = Notification.Name("scanResult")
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
