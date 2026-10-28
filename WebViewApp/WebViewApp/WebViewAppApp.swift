import SwiftUI

@main
struct WebViewAppApp: App {
    @State private var isRegistered: Bool = false
    @State private var showWebView: Bool = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if showWebView {
                    ContentView()
                        .ignoresSafeArea()
                } else {
                    RegisterView(onRegisterSuccess: {
                        showWebView = true
                    })
                    .ignoresSafeArea()
                }
            }
            .statusBarHidden(true)
            .preferredColorScheme(.light)
            .onAppear {
                checkRegistrationStatus()
                setupNotificationObservers()
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .tokenMissing,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 [Native] 收到 tokenMissing 通知，返回注册页")
            showWebView = false
        }
    }
    
    private func checkRegistrationStatus() {
        if AppConfig.shared.forceReRegister {
            print("📱 [Native] 配置了强制重新注册，进入注册页")
            showWebView = false
            return
        }
        let hasToken = RegisterAPIService.shared.getToken() != nil
        print("📱 [Native] 检查注册状态: \(hasToken ? "已注册" : "未注册")")
        if hasToken {
            showWebView = true
        }
    }
}
