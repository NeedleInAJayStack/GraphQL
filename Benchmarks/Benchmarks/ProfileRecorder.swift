import Foundation
import ProfileRecorder

/// Starts sampling in the background and writes raw samples to the file at `PROFILE_RECORDER_OUTPUT`,
/// but only when that variable is set, so normal benchmark runs are unaffected.
///
/// Example:
///
///     PROFILE_RECORDER_OUTPUT=/tmp/graphql-bench.swipr swift package benchmark --filter graphql
///
///     swift run swipr-sample-conv /tmp/graphql-bench.swipr > samples.perf
///
/// Samples are raw (unsymbolicated); convert them with `swipr-sample-conv` from swift-profile-recorder.
func startProfileRecorderIfRequested() {
    guard let outputPath = ProcessInfo.processInfo.environment["PROFILE_RECORDER_OUTPUT"] else {
        return
    }

    Task.detached {
        do {
            try await ProfileRecorderSampler.sharedInstance.requestSamples(
                outputFilePath: outputPath,
                failIfFileExists: false,
                count: 1000,
                timeBetweenSamples: .milliseconds(10)
            )
            FileHandle.standardError.write(Data("Profile samples written to \(outputPath)\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("Profile recorder failed: \(error)\n".utf8))
        }
    }
}
