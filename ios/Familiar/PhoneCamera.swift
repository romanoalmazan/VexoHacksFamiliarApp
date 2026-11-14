import AVFoundation
import CoreImage
import SwiftUI
import UIKit

/// The iPhone's camera, giving one small JPEG a second. GlassesCamera gives the same from
/// the Meta glasses; FacesView uses whichever is chosen.
final class PhoneCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// Called about once a second with a JPEG, on the main thread.
    var onFrame: ((Data) -> Void)?
    /// Why there are no pictures, as a sentence, or nil when all is well. Main thread.
    var onProblem: ((String?) -> Void)?

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "familiar.camera")
    private let context = CIContext()
    private var front = false
    private var lastSent = Date.distantPast
    private var latest: Data?
    private let lock = NSLock()

    static let secondsBetweenPictures: TimeInterval = 1
    static let longestSide: CGFloat = 960

    /// The newest picture, for enrolling the face in view.
    var latestJPEG: Data? {
        lock.lock(); defer { lock.unlock() }
        return latest
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            guard let self else { return }
            guard allowed else {
                self.report("Familiar may not use the camera. Allow it in Settings → Familiar.")
                return
            }
            self.queue.async { self.configure(); self.session.startRunning() }
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    func flip() {
        queue.async { self.front.toggle(); self.configure() }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        session.sessionPreset = .hd1280x720
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            report("This device has no camera to use. (The Simulator has none: choose a photo instead.)")
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90          // the app is portrait only
        }
        report(nil)
    }

    private func report(_ problem: String?) {
        DispatchQueue.main.async { self.onProblem?(problem) }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastSent) >= Self.secondsBetweenPictures,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastSent = Date()
        var image = CIImage(cvPixelBuffer: pixels)
        let scale = Self.longestSide / max(image.extent.width, image.extent.height)
        if scale < 1 { image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) }
        guard let jpeg = context.jpegRepresentation(of: image, colorSpace: CGColorSpaceCreateDeviceRGB(),
                                                    options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.7]) else { return }
        lock.lock(); latest = jpeg; lock.unlock()
        DispatchQueue.main.async { self.onFrame?(jpeg) }
    }

    /// Any photo (HEIC, huge, rotated) as an upright JPEG small enough to send.
    static func jpeg(from photo: Data) -> Data? {
        guard let image = UIImage(data: photo) else { return nil }
        let scale = min(1, longestSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// What the camera sees, live.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class Layered: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    }

    func makeUIView(context: Context) -> Layered {
        let view = Layered()
        if let layer = view.layer as? AVCaptureVideoPreviewLayer {
            layer.session = session
            layer.videoGravity = .resizeAspectFill
        }
        return view
    }

    func updateUIView(_ view: Layered, context: Context) {}
}
