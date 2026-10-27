import Foundation
import UIKit

struct RegisterInfo: Decodable {
    let siteDeviceName: String
    let deviceNo: String
    let siteName: String
}

struct RegisterResult: Decodable {
    let token: String?
}

class RegisterAPIService {
    static let shared = RegisterAPIService()
    
    private init() {}
    
    private var baseURL: String {
        return AppConfig.shared.baseURL
    }
    
    private let machineIdKey = "MACHINE_ID"
    
    func getMachineId() -> String {
        if let saved = KeychainManager.load(key: machineIdKey) {
            print("📱 [Native] 从 Keychain 获取设备 ID: \(saved)")
            return saved
        }
        let uuid = UIDevice.current.identifierForVendor?.uuidString.replacingOccurrences(of: "-", with: "") ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        _ = KeychainManager.save(key: machineIdKey, value: uuid)
        print("📱 [Native] 设备 ID 已保存到 Keychain: \(uuid)")
        return uuid
    }
    
    func getSiteInfo(deviceNo: String) async throws -> RegisterInfo {
        let machineId = getMachineId()+"8"
        let urlString = "\(baseURL)/llk-api/llk/auth/register-confirmation?deviceNo=\(deviceNo)"
        
        print("📱 [Native] ===== 获取站点信息请求 =====")
        print("📱 [Native] 请求方式: GET")
        print("📱 [Native] 完整 URL: \(urlString)")
        print("📱 [Native] 请求头: machineid=\(machineId)")
        print("📱 [Native] 请求参数: deviceNo=\(deviceNo)")
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "RegisterAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL 错误"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(machineId, forHTTPHeaderField: "machineid")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RegisterAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "响应错误"])
        }
        
        print("📱 [Native] HTTP 状态码: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📱 [Native] 响应原始数据: \(responseString)")
        }
        
        if httpResponse.statusCode >= 500 {
            print("📱 [Native] 获取站点信息失败: 服务器错误 (5xx)")
            throw NSError(domain: "RegisterAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器错误"])
        }
        
        if httpResponse.statusCode >= 400 {
            print("📱 [Native] 获取站点信息失败: 客户端错误 (4xx)")
            throw NSError(domain: "RegisterAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "朗讀機編號有誤"])
        }
        
        let result = try JSONDecoder().decode(RegisterInfo.self, from: data)
        print("📱 [Native] 解码后结果:")
        print("📱 [Native]   deviceNo: \(result.deviceNo)")
        print("📱 [Native]   siteDeviceName: \(result.siteDeviceName)")
        print("📱 [Native]   siteName: \(result.siteName)")
        print("📱 [Native] =========================")
        return result
    }
    
    func register(deviceNo: String) async throws -> Bool {
        let machineId = getMachineId()+"8"
        let urlString = "\(baseURL)/llk-api/llk/auth/register"
        
        print("📱 [Native] ======== 注册请求 ========")
        print("📱 [Native] 请求方式: POST")
        print("📱 [Native] 完整 URL: \(urlString)")
        print("📱 [Native] 请求头: machineid=\(machineId)")
        
        let body: [String: String] = ["deviceNo": deviceNo]
        print("📱 [Native] 请求参数 (body):")
        if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("📱 [Native]   \(bodyString)")
        }
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "RegisterAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL 错误"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(machineId, forHTTPHeaderField: "machineid")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "RegisterAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "响应错误"])
        }
        
        print("📱 [Native] HTTP 状态码: \(httpResponse.statusCode)")
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("📱 [Native] 响应原始数据: \(responseString)")
        }
        
        if httpResponse.statusCode >= 400 {
            print("📱 [Native] 注册失败: HTTP \(httpResponse.statusCode)")
            print("📱 [Native] =========================")
            throw NSError(domain: "RegisterAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "注册失败"])
        }
        
        let result = try JSONDecoder().decode(RegisterResult.self, from: data)
        
        print("📱 [Native] 解码后结果:")
        if let token = result.token {
            print("📱 [Native]   token: \(token.prefix(10))... (已隐藏完整值)")
            _ = KeychainManager.save(key: "TOKEN", value: token)
            print("📱 [Native] 注册成功，Token 已保存到 Keychain")
            print("📱 [Native] =========================")
            return true
        } else {
            print("📱 [Native]   token: 空")
            print("📱 [Native] 注册失败: 无 token 返回")
            print("📱 [Native] =========================")
            return false
        }
    }
    
    func getToken() -> String? {
        return KeychainManager.load(key: "TOKEN")
    }
    
    func clearToken() {
        KeychainManager.delete(key: "TOKEN")
    }
}
