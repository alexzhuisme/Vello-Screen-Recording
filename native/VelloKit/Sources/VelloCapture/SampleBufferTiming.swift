import CoreMedia

enum SampleBufferTiming {
    /// Returns a copy of `sampleBuffer` with every timestamp shifted earlier by `offset`.
    ///
    /// Pausing works by leaving a gap in the incoming timestamps and then
    /// subtracting that gap from everything that follows, so the written file has
    /// a continuous timeline.
    static func copy(_ sampleBuffer: CMSampleBuffer, shiftedBy offset: CMTime) -> CMSampleBuffer? {
        guard offset != .zero else { return sampleBuffer }

        var count: CMItemCount = 0
        guard CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &count
        ) == noErr else { return nil }

        var timings = [CMSampleTimingInfo](repeating: .invalid, count: Int(count))
        guard CMSampleBufferGetSampleTimingInfoArray(
            sampleBuffer,
            entryCount: count,
            arrayToFill: &timings,
            entriesNeededOut: &count
        ) == noErr else { return nil }

        for index in 0..<Int(count) {
            if timings[index].presentationTimeStamp.isValid {
                timings[index].presentationTimeStamp = timings[index].presentationTimeStamp - offset
            }
            if timings[index].decodeTimeStamp.isValid {
                timings[index].decodeTimeStamp = timings[index].decodeTimeStamp - offset
            }
        }

        var output: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: count,
            sampleTimingArray: &timings,
            sampleBufferOut: &output
        ) == noErr else { return nil }

        return output
    }
}
