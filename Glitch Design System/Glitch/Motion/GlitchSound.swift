import AVFoundation
import SwiftUI

/// Two clicks and a thud.
///
/// The most underrated part of how hardware feels, and the reason a mechanical
/// keyboard or a Teenage Engineering box is loved out of proportion to what it
/// does. A crossing tick, a landing click and a rejection thud carry more
/// perceived quality than any amount of additional motion.
///
/// The waveforms are synthesised at launch rather than shipped as files: a
/// click is a few milliseconds of decaying tone, which is less code to
/// generate than to load.
///
/// Deliberately quiet, mixed with other audio, and silenced by the hardware
/// switch — an interface that talks over someone's music has misunderstood the
/// assignment.
@MainActor
public final class GlitchSound {
    public static let shared = GlitchSound()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [Voice: AVAudioPCMBuffer] = [:]
    private var isReady = false
    private var didFail = false

    private enum Voice: Hashable {
        case tick, commit, reject

        /// Pitched so the three are distinguishable without being musical:
        /// crossing is high and thin, landing lower and rounder, rejection
        /// low and short.
        var frequency: Double {
            switch self {
            case .tick: 2400
            case .commit: 1400
            case .reject: 320
            }
        }

        var duration: Double {
            switch self {
            case .tick: 0.012
            case .commit: 0.030
            case .reject: 0.070
            }
        }

        var level: Float {
            switch self {
            case .tick: 0.05
            case .commit: 0.10
            case .reject: 0.12
            }
        }
    }

    private init() {}

    // MARK: - Public

    /// A notch crossed while dragging. Fires often, so it is the quietest.
    public static func tick() { shared.play(.tick) }
    /// A value landed.
    public static func commit() { shared.play(.commit) }
    /// A value refused.
    public static func reject() { shared.play(.reject) }

    // MARK: - Engine

    private func play(_ voice: Voice) {
        prepareIfNeeded()
        guard isReady, let buffer = buffers[voice] else { return }

        // `.interrupts` rather than queueing: during a fast drag the ticks
        // would otherwise pile into a buzz.
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        if !player.isPlaying { player.play() }
    }

    private func prepareIfNeeded() {
        guard !isReady, !didFail else { return }

        #if os(iOS)
        // Ambient: mixes with whatever else is playing, and obeys the ring
        // switch. Anything louder would be presumptuous for a slider.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        guard let format else {
            didFail = true
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        for voice in [Voice.tick, .commit, .reject] {
            buffers[voice] = Self.makeClick(voice: voice, format: format)
        }

        do {
            try engine.start()
            isReady = true
        } catch {
            // No audio route, no permission, no problem — everything else
            // about the control still works.
            didFail = true
        }
    }

    /// A decaying sine with a touch of noise in the attack, which is what
    /// separates a click from a beep.
    private nonisolated static func makeClick(
        voice: Voice,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * voice.duration)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frames
        let decay = 6.0 / voice.duration

        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            let envelope = exp(-decay * t)
            let tone = sin(2 * .pi * voice.frequency * t)
            let attack = t < 0.001 ? Double.random(in: -0.5...0.5) : 0
            channel[frame] = Float((tone + attack) * envelope) * voice.level
        }
        return buffer
    }
}
