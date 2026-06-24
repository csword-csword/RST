import AVFoundation
import SwiftUI
import Vision

/// Live rear-camera view that runs on-device text recognition (Vision) on the
/// frames and reports the recognized strings, so the scan screen can match a
/// machine from the text printed on its label/placard. Renders a placeholder on
/// the simulator (no camera) so the flow stays usable.
struct LabelScannerView: UIViewControllerRepresentable {
    var onText: ([String]) -> Void

    func makeUIViewController(context: Context) -> LabelScannerController {
        let controller = LabelScannerController()
        controller.onText = onText
        return controller
    }

    func updateUIViewController(_ controller: LabelScannerController, context: Context) {
        controller.onText = onText
    }
}

final class LabelScannerController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onText: (([String]) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoQueue = DispatchQueue(label: "fitness.pinpoint.scanner")
    private let request = VNRecognizeTextRequest()
    private var lastRun = Date.distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        configureSession()
    }

    private func configureSession() {
        #if targetEnvironment(simulator)
        return
        #else
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        let captureSession = session
        Task.detached(priority: .userInitiated) { captureSession.startRunning() }
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let captureSession = session
        Task.detached { if captureSession.isRunning { captureSession.stopRunning() } }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Throttle OCR to a few frames per second.
        let now = Date()
        guard now.timeIntervalSince(lastRun) > 0.4 else { return }
        lastRun = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])

        let strings = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        guard !strings.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in self?.onText?(strings) }
    }
}
