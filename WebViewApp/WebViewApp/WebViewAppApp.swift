import SwiftUI

@main
struct WebViewAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBarHidden(true) // 隐藏顶部状态栏
                .preferredColorScheme(.light) // 锁定浅色模式，避免网页颜色异常
        }
    }
}
