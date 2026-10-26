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
            }
        }
    }
    
    private func checkRegistrationStatus() {
        let hasToken = RegisterAPIService.shared.getToken() != nil
        print("📱 [Native] 检查注册状态: \(hasToken ? "已注册" : "未注册")")
        if hasToken {
            showWebView = true
        }
    }
}
