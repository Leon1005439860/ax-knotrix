import SwiftUI

struct RegisterView: View {
    @State private var deviceNo: String = ""
    @State private var step: Int = 0
    @State private var errorText: String = ""
    @State private var registerInfo: RegisterInfo?
    @State private var isLoading: Bool = false
    @State private var showWebView: Bool = false
    
    var onRegisterSuccess: (() -> Void)?
    
    var body: some View {
        ZStack {
            backgroundView
                .ignoresSafeArea()
            
            registerDialog
                .padding(.horizontal, 60)
        }
        .fullScreenCover(isPresented: $showWebView) {
            ContentView()
                .ignoresSafeArea()
        }
    }
    
    private var backgroundView: some View {
        Group {
            if let bgImage = UIImage(named: "bg") {
                Image(uiImage: bgImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.92, green: 0.92, blue: 0.98),
                        Color(red: 0.95, green: 0.93, blue: 0.98)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    private var registerDialog: some View {
        VStack(spacing: 0) {
            headerView
            bodyView
            footerView
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 4)
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            if let logoImage = UIImage(named: "icon_logo_primary") {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.purple, .blue]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("LLK")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            Text("Reader Station")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(red: 0.34, green: 0.33, blue: 0.38))
        }
        .padding(.top, 40)
        .padding(.bottom, 30)
    }
    
    @ViewBuilder
    private var bodyView: some View {
        if step == 0 {
            inputStepView
        } else {
            confirmStepView
        }
    }
    
    private var inputStepView: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("朗讀機編號", text: $deviceNo)
                .font(.system(size: 18))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                .cornerRadius(8)
                .keyboardType(.numberPad)
                .onChange(of: deviceNo) { newValue in
                    if newValue.count > 5 {
                        deviceNo = String(newValue.prefix(5))
                    }
                    errorText = ""
                }
            
            if !errorText.isEmpty {
                Text(errorText)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
    
    private var confirmStepView: some View {
        VStack(spacing: 12) {
            Text(registerInfo?.deviceNo ?? "")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.34, green: 0.33, blue: 0.38))
            
            Text(registerInfo?.siteDeviceName ?? "")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.34, green: 0.33, blue: 0.38))
            
            Text(registerInfo?.siteName ?? "")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.54, green: 0.53, blue: 0.58))
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
    
    private var footerView: some View {
        HStack(spacing: 16) {
            if step > 0 {
                Button(action: handleBack) {
                    Text("返回")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(red: 0.34, green: 0.33, blue: 0.38))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.92, green: 0.92, blue: 0.95))
                        .cornerRadius(8)
                }
            }
            
            Button(action: handleConfirm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple.opacity(0.5))
                        .cornerRadius(8)
                } else {
                    Text(step == 0 ? "認證" : "開始使用")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(confirmButtonColor)
                        .cornerRadius(8)
                }
            }
            .disabled(isLoading || (step == 0 && deviceNo.isEmpty))
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
    
    private var confirmButtonColor: Color {
        if step == 0 && deviceNo.isEmpty {
            return Color.purple.opacity(0.4)
        }
        return Color(red: 0.4, green: 0.35, blue: 0.9)
    }
    
    private func handleBack() {
        step -= 1
        errorText = ""
    }
    
    private func handleConfirm() {
        if step == 0 {
            deviceNo = deviceNo.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !deviceNo.isEmpty else {
                errorText = "朗讀機編號有誤"
                return
            }
            Task {
                await doGetSiteInfo()
            }
        } else {
            Task {
                await doRegister()
            }
        }
    }
    
    @MainActor
    private func doGetSiteInfo() async {
        isLoading = true
        errorText = ""
        do {
            let info = try await RegisterAPIService.shared.getSiteInfo(deviceNo: deviceNo)
            registerInfo = info
            deviceNo = info.deviceNo
            step += 1
        } catch {
            print("📱 [Native] 获取站点信息失败: \(error)")
            let nsError = error as NSError
            if nsError.code < 500 {
                errorText = "朗讀機編號有誤"
            } else {
                errorText = "網絡錯誤，請重試"
            }
        }
        isLoading = false
    }
    
    @MainActor
    private func doRegister() async {
        isLoading = true
        do {
            let success = try await RegisterAPIService.shared.register(deviceNo: deviceNo)
            if success {
                showWebView = true
                onRegisterSuccess?()
            } else {
                print("📱 [Native] 注册失败，无 token")
            }
        } catch {
            print("📱 [Native] 注册失败: \(error)")
            errorText = "註冊失敗，請重試"
            step = 0
        }
        isLoading = false
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
    }
}
