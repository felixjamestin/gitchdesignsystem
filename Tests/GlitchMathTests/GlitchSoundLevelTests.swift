import AVFoundation
import XCTest
@testable import GlitchDesignSystem

/// The system's loudness is calibrated the way the Glitch Sound FX library
/// calibrates its palette: the loudest voice lands just under a 0.72 peak
/// ceiling, and nothing ever exceeds it.
@MainActor
final class GlitchSoundLevelTests: XCTestCase {
    private var format: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    }

    func testLoudestVoiceLandsJustUnderTheCeiling() throws {
        var peaks: [Float] = []
        for voice in GlitchSound.Voice.allCases {
            let buffer = try XCTUnwrap(GlitchSound.render(voice.recipe, format: format),
                                       "\(voice) failed to render")
            peaks.append(peak(of: buffer))
        }
        let loudest = try XCTUnwrap(peaks.max())
        XCTAssertLessThanOrEqual(loudest, 0.72, "limiter must hold the ceiling")
        XCTAssertGreaterThan(loudest, 0.60, "boost should land the loudest voice near the ceiling")
    }

    func testNoVoiceClipsAtAnyPitchVariant() throws {
        for voice in GlitchSound.Voice.allCases {
            for rate in [0.94, 1.0, 1.06] {
                let buffer = try XCTUnwrap(
                    GlitchSound.render(voice.recipe.pitched(by: rate), format: format))
                XCTAssertLessThanOrEqual(peak(of: buffer), 0.72,
                                         "\(voice) at rate \(rate) exceeds the ceiling")
            }
        }
    }

    private func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        return (0..<Int(buffer.frameLength)).reduce(Float.zero) { current, frame in
            max(current, abs(channel[frame]))
        }
    }
}
