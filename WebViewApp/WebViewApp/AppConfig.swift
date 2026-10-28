import Foundation

class AppConfig {
    static let shared = AppConfig()
    
    private init() {}
    
    // MARK: - 服务器配置
    let baseURL: String = "https://sit-k-library.accentrix.com"
    //let baseURL: String = "http://192.168.118.157:5173"
    
    // MARK: - 注册配置
    /// 是否强制重新注册：true 时跳过 token 检查，每次启动都进入注册页
    let forceReRegister: Bool = false
    
    // MARK: - WebView 配置
    var webViewURL: String {
        return "\(baseURL)/llk-webapp/#/"
    }
}
