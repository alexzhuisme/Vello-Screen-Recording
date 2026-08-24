import AVFoundation
import CoreMedia
import Observation
import VelloCapture

enum MicrophoneMonitorStatus: Sendable, Equatable {
    case inactive
    case monitoring
    case permissionDenied
    case unavailable
}

/// Lightweight preflight meter. It is stopped before ScreenCaptureKit starts so
/// the selected input is released for the actual recording session.
@MainActor
@Observable
final class MicrophoneLevelMonitor: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    private(set) var level: Double = 0
    private(set) var status: MicrophoneMonitorStatus = .inactive
    private(set) var isSilent = false

    @ObservationIgnored private var session: AVCaptureSession?
    @ObservationIgnored private let sampleQueue = DispatchQueue(
        label: "com.yueming.Vello.microphone-meter",
        qos: .userInteractive
    )
    @ObservationIgnored private var monitoringStartedAt: Date?
    @ObservationIgnored private var lastAudibleAt: Date?

    func start(deviceID: String?) async {
        stop()

        if Permissions.microphoneStatus == .notDetermined {
            _ = await Permissions.requestMicrophoneAccess()
        }
        guard Permissions.microphoneStatus == .granted else {
            status = .permissionDenied
            return
        }
        guard let resolvedID = CaptureDevices.resolveAudioDeviceID(deviceID),
              let device = AVCaptureDevice(uniqueID: resolvedID)
        else {
            status = .unavailable
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureAudioDataOutput()
            output.audioSettings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: false,
                AVNumberOfChannelsKey: 1,
                AVSampleRateKey: 48_000
            ]
            output.setSampleBufferDelegate(self, queue: sampleQueue)

            let session = AVCaptureSession()
            session.beginConfiguration()
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                status = .unavailable
                return
            }
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()
            session.startRunning()

            self.session = session
            status = .monitoring
            monitoringStartedAt = .now
        } catch {
            status = .unavailable
        }
    }

    func stop() {
        if let session, session.isRunning {
            session.stopRunning()
        }
        session = nil
        level = 0
        status = .inactive
        isSilent = false
        monitoringStartedAt = nil
        lastAudibleAt = nil
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let measured = Self.normalizedLevel(in: sampleBuffer)
        Task { @MainActor [weak self] in
            guard let self, self.status == .monitoring else { return }
            self.level = self.level * 0.72 + measured * 0.28
            if measured > 0.06 {
                self.lastAudibleAt = .now
                self.isSilent = false
            } else if let started = self.monitoringStartedAt,
                      Date.now.timeIntervalSince(self.lastAudibleAt ?? started) > 2 {
                self.isSilent = true
            }
        }
    }

    nonisolated private static func normalizedLevel(in sampleBuffer: CMSampleBuffer) -> Double {
        var audioBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
        )
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr,
              let data = audioBufferList.mBuffers.mData,
              audioBufferList.mBuffers.mDataByteSize >= MemoryLayout<Float>.size
        else { return 0 }

        let count = Int(audioBufferList.mBuffers.mDataByteSize) / MemoryLayout<Float>.size
        let samples = data.assumingMemoryBound(to: Float.self)
        var sum: Double = 0
        for index in 0..<count {
            let value = Double(samples[index])
            sum += value * value
        }
        let rms = sqrt(sum / Double(count))
        let decibels = 20 * log10(max(rms, 0.000_01))
        return min(max((decibels + 50) / 50, 0), 1)
    }
}
