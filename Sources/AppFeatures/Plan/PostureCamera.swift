#if os(iOS)
import AVFoundation
import Vision
import SwiftUI
import GrowthCore

/// Front-camera body-pose tracking for the posture check. Frames are analysed on the device with Apple's Vision
/// framework and immediately discarded: no image or video is stored or sent anywhere. Only joint positions leave
/// this class.
final class PostureCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Status: Equatable {
        case idle, unavailable, denied, running
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var landmarks: BodyLandmarks?
    /// Size of the analysed (portrait) frame, used to place overlay dots over the preview.
    @Published private(set) var frameSize: CGSize = CGSize(width: 3, height: 4)

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.stature.posture.camera")
    private var configured = false
    private var lastAnalysis = Date.distantPast

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndRun() } else { self?.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                      let input = try? AVCaptureDeviceInput(device: device) else {
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720
                if self.session.canAddInput(input) { self.session.addInput(input) }
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.queue)
                if self.session.canAddOutput(output) { self.session.addOutput(output) }
                if let connection = output.connection(with: .video) {
                    if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                    if connection.isVideoMirroringSupported { connection.isVideoMirrored = true }
                }
                self.session.commitConfiguration()
                self.configured = true
            }
            self.session.startRunning()
            DispatchQueue.main.async { self.status = .running }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // About 12 analyses a second is plenty and keeps the phone cool.
        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) > 0.08, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now
        let size = CGSize(width: CVPixelBufferGetWidth(pixels), height: CVPixelBufferGetHeight(pixels))
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up)
        try? handler.perform([request])
        let points = request.results?.first.map(Self.landmarks(from:))
        DispatchQueue.main.async {
            self.frameSize = size
            self.landmarks = points
        }
    }

    static func landmarks(from observation: VNHumanBodyPoseObservation) -> BodyLandmarks {
        func point(_ joint: VNHumanBodyPoseObservation.JointName) -> BodyPoint? {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.3 else { return nil }
            return BodyPoint(x: Double(p.location.x), y: Double(p.location.y))
        }
        return BodyLandmarks(nose: point(.nose), leftEye: point(.leftEye), rightEye: point(.rightEye), leftEar: point(.leftEar),
                             rightEar: point(.rightEar), leftShoulder: point(.leftShoulder), rightShoulder: point(.rightShoulder),
                             leftHip: point(.leftHip), rightHip: point(.rightHip))
    }
}

/// Live camera preview filling its frame (aspect fill), matching how `PostureOverlay` maps points.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// Dots and lines over the preview for the joints the check uses, so people can see what's being measured.
struct PostureOverlay: View {
    let landmarks: BodyLandmarks?
    let frameSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard let landmarks else { return }
                let scale = max(size.width / frameSize.width, size.height / frameSize.height)
                let offset = CGPoint(x: (size.width - frameSize.width * scale) / 2, y: (size.height - frameSize.height * scale) / 2)
                func map(_ p: BodyPoint?) -> CGPoint? {
                    guard let p else { return nil }
                    return CGPoint(x: offset.x + p.x * frameSize.width * scale, y: offset.y + (1 - p.y) * frameSize.height * scale)
                }
                let gold = Color(red: 0.91, green: 0.78, blue: 0.48)
                for (a, b) in [(landmarks.leftShoulder, landmarks.rightShoulder), (landmarks.leftHip, landmarks.rightHip),
                               (landmarks.leftEar, landmarks.leftShoulder), (landmarks.rightEar, landmarks.rightShoulder)] {
                    if let pa = map(a), let pb = map(b) {
                        var path = Path()
                        path.move(to: pa)
                        path.addLine(to: pb)
                        context.stroke(path, with: .color(gold.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                }
                for p in [landmarks.nose, landmarks.leftEye, landmarks.rightEye, landmarks.leftEar, landmarks.rightEar,
                          landmarks.leftShoulder, landmarks.rightShoulder, landmarks.leftHip, landmarks.rightHip].compactMap(map) {
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(gold))
                    context.stroke(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12)), with: .color(.black.opacity(0.4)), lineWidth: 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
