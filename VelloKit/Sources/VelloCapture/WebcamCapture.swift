import AVFoundation
import CoreMedia

/// Captures the latest camera frame for direct composition into screen frames.
/// Keeping this separate from ScreenCaptureKit makes the bubble work for both
/// display regions and true moving-window captures.
final class WebcamCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    private let outputQueue = DispatchQueue(label: "com.yueming.Vello.webcam", qos: .userInteractive)
    private let lock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?

    init(deviceID: String) throws {
        super.init()

        guard let device = AVCaptureDevice(uniqueID: deviceID) else {
            throw RecordingError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: outputQueue)

        session.beginConfiguration()
        session.sessionPreset = .high
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            throw RecordingError.cameraUnavailable
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        session.startRunning()
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        lock.withLock { latestPixelBuffer = nil }
    }

    func currentPixelBuffer() -> CVPixelBuffer? {
        lock.withLock { latestPixelBuffer }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.withLock { latestPixelBuffer = imageBuffer }
    }
}
