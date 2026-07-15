import SwiftUI
import AVFoundation

struct ScannerView: View {
    @StateObject private var scannerDelegate = ScannerDelegate()
    let onResult: (String) -> Void
    let onClose: () -> Void
    let onError: (String) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ScannerPreviewView(session: scannerDelegate.session)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    Button(action: {
                        print("📱 [Native] 用户取消扫码")
                        onClose()
                    }) {
                        Text("取消")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 80)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            scannerDelegate.onResult = onResult
            scannerDelegate.onError = onError
            scannerDelegate.startScanning()
        }
        .onDisappear {
            scannerDelegate.stopScanning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
class ScannerDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate, ObservableObject {
    let session = AVCaptureSession()
    var onResult: ((String) -> Void)?
    var onError: ((String) -> Void)?
    private var isProcessed = false
    
    func startScanning() {
        isProcessed = false
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("📱 [Native] 无法访问相机设备")
            onError?("无法访问相机")
            return
        }
        
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            print("📱 [Native] 无法创建相机输入")
            onError?("无法创建相机输入")
            return
        }
        
        session.beginConfiguration()
        
        // 移除旧输入输出，防止重复添加
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr, .code128, .code39, .code93, .ean13, .ean8, .pdf417, .aztec, .dataMatrix]
        }
        
        session.commitConfiguration()
        session.startRunning()
        print("📱 [Native] 相机扫码已启动")
    }
    
    func stopScanning() {
        session.stopRunning()
        print("📱 [Native] 相机扫码已停止")
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isProcessed, let object = metadataObjects.first,
              let readableObject = object as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        isProcessed = true
        print("📱 [Native] 扫码结果: \(stringValue)")
        
        // 震动反馈
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        onResult?(stringValue)
    }
}

// MARK: - 相机预览视图
struct ScannerPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.needsDisplayOnBoundsChange = true
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}