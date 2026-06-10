import AVFoundation
import Observation
import SwiftUI

/// Live rear-camera preview used by the scan screens. On the simulator, or
/// when camera permission is missing, it renders a placeholder so the scan
/// flow stays fully demoable.
struct CameraPreview: View {
    @State private var session = CameraSession()

    var body: some View {
        ZStack {
            if session.isRunning {
                CameraLayerView(session: session.captureSession)
            } else {
                placeholder
            }
        }
        .task { await session.start() }
        .onDisappear { session.stop() }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.12), Color(white: 0.04)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Camera preview")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@Observable
final class CameraSession {
    let captureSession = AVCaptureSession()
    private(set) var isRunning = false

    func start() async {
        #if !targetEnvironment(simulator)
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { return }
        if captureSession.inputs.isEmpty {
            captureSession.beginConfiguration()
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            captureSession.commitConfiguration()
        }
        let session = captureSession
        Task.detached(priority: .userInitiated) {
            session.startRunning()
        }
        isRunning = true
        #endif
    }

    func stop() {
        #if !targetEnvironment(simulator)
        let session = captureSession
        Task.detached {
            session.stopRunning()
        }
        isRunning = false
        #endif
    }
}

struct CameraLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
