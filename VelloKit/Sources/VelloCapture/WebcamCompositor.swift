import CoreImage
import CoreMedia
import CoreVideo
import VelloCore

/// GPU-backed circular picture-in-picture compositor used before video encoding.
final class WebcamCompositor: @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: true])
    private let canvasSize: CGSize
    private let bubbleFrame: CGRect
    private let bubbleMask: CIImage?
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var pool: CVPixelBufferPool?
    private var formatDescription: CMVideoFormatDescription?

    init(configuration: WebcamConfiguration, canvasSize: CGSize) {
        self.canvasSize = canvasSize
        let resolvedBubbleFrame = configuration.size.frame(
            in: canvasSize,
            position: configuration.position,
            customPosition: configuration.customPosition
        )
        bubbleFrame = resolvedBubbleFrame
        let center = CIVector(x: resolvedBubbleFrame.midX, y: resolvedBubbleFrame.midY)
        let radius = resolvedBubbleFrame.width / 2
        bubbleMask = CIFilter(
            name: "CIRadialGradient",
            parameters: [
                "inputCenter": center,
                "inputRadius0": max(0, radius - 1.5),
                "inputRadius1": radius,
                "inputColor0": CIColor.white,
                "inputColor1": CIColor.clear
            ]
        )?.outputImage?.cropped(to: resolvedBubbleFrame)
        pool = Self.makePool(size: canvasSize)
    }

    func composite(screen sampleBuffer: CMSampleBuffer, webcam webcamBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        guard let screenBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let outputBuffer = makeOutputBuffer()
        else { return nil }

        let canvas = CIImage(cvPixelBuffer: screenBuffer)
        let camera = Self.cameraImage(from: webcamBuffer, fittedTo: bubbleFrame)

        guard let bubbleMask,
              let composed = CIFilter(
                name: "CIBlendWithMask",
                parameters: [
                    kCIInputImageKey: camera,
                    kCIInputBackgroundImageKey: canvas,
                    kCIInputMaskImageKey: bubbleMask
                ]
              )?.outputImage
        else { return nil }

        context.render(
            composed,
            to: outputBuffer,
            bounds: CGRect(origin: .zero, size: canvasSize),
            colorSpace: colorSpace
        )

        if formatDescription == nil {
            guard CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: outputBuffer,
                formatDescriptionOut: &formatDescription
            ) == noErr else { return nil }
        }
        guard let formatDescription else { return nil }

        var timing = CMSampleTimingInfo()
        guard CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0, timingInfoOut: &timing) == noErr else {
            return nil
        }

        var outputSample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: outputBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &outputSample
        ) == noErr else { return nil }
        return outputSample
    }

    private static func cameraImage(from pixelBuffer: CVPixelBuffer, fittedTo frame: CGRect) -> CIImage {
        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = image.extent
        let squareSide = min(extent.width, extent.height)
        let square = CGRect(
            x: extent.midX - squareSide / 2,
            y: extent.midY - squareSide / 2,
            width: squareSide,
            height: squareSide
        )
        image = image.cropped(to: square)

        let mirror = CGAffineTransform(translationX: square.maxX + square.minX, y: 0)
            .scaledBy(x: -1, y: 1)
        image = image.transformed(by: mirror)

        let scale = frame.width / squareSide
        return image
            .transformed(by: CGAffineTransform(translationX: -square.minX, y: -square.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: frame.minX, y: frame.minY))
            .cropped(to: frame)
    }

    private func makeOutputBuffer() -> CVPixelBuffer? {
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess else {
            return nil
        }
        return buffer
    }

    private static func makePool(size: CGSize) -> CVPixelBufferPool? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: Int(size.width),
            kCVPixelBufferHeightKey: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool)
        return pool
    }
}
