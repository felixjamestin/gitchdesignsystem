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
    /// Several renderings per voice, at slightly different pitches. A tick
    /// that is identical every time reads as a machine gun after twenty
    /// crossings; a few cents of variation is what a physical mechanism does,
    /// and the ear forgives it indefinitely.
    private var buffers: [Voice: [AVAudioPCMBuffer]] = [:]
    private var lastVariant: [Voice: Int] = [:]
    private var isReady = false
    private var didFail = false
    private var lastPlayful: Voice?

    /// A synthesised sound, described rather than recorded.
    ///
    /// Everything the system says is one oscillator with a pitch envelope, a
    /// little vibrato and an amplitude decay — which is enough for a click, a
    /// beep and, with a slow sweep up and back down, something that reads as a
    /// small animal.
    struct Recipe {
        /// Pitch at the start, and where it heads.
        var start: Double
        var end: Double
        /// An optional turning point, reached halfway. A single sweep can only
        /// rise or fall; a cry has to do both.
        var peak: Double?
        var duration: Double
        var level: Float
        /// Wobble depth in Hz, and how fast. What separates a squeak from a
        /// whistle.
        var vibrato: Double = 0
        var vibratoRate: Double = 0
        /// Noise mixed into the first millisecond. What makes a click a click
        /// rather than a beep.
        var noise: Double = 0
        /// How sharply the amplitude falls away.
        var decay: Double = 6
        /// Blends the sine toward a square. Cheap way to sound like a toy.
        var square: Double = 0

        /// The same recipe transposed, for the pitch-varied variants.
        func pitched(by rate: Double) -> Recipe {
            var copy = self
            copy.start *= rate
            copy.end *= rate
            if let peak { copy.peak = peak * rate }
            return copy
        }
    }

    enum Voice: Hashable, CaseIterable {
        // The working vocabulary.
        case tick, commit, reject
        // The playful one, for when someone pokes the speaker.
        case beep, boop, bleep, chirp, squeak, meow, purr, warble, blip

        /// Everything a poke can produce. Deliberately varied in length and
        /// register — a random pick from nine similar sounds reads as one
        /// sound misfiring, not as playfulness.
        static let playful: [Voice] = [
            .beep, .boop, .bleep, .chirp, .squeak, .meow, .purr, .warble, .blip,
        ]

        /// What to call it on screen. Lowercase: these are noises, not labels.
        var name: String {
            switch self {
            case .tick: "tick"
            case .commit: "click"
            case .reject: "nope"
            case .beep: "beep"
            case .boop: "boop"
            case .bleep: "bleep"
            case .chirp: "chirp"
            case .squeak: "squeak"
            case .meow: "meow"
            case .purr: "purr"
            case .warble: "warble"
            case .blip: "blip"
            }
        }

        var recipe: Recipe {
            switch self {
            // Pitched so the three are distinguishable without being musical:
            // crossing is high and thin, landing lower and rounder, rejection
            // low and short.
            case .tick:
                Recipe(start: 2400, end: 2400, peak: nil, duration: 0.012, level: 0.05, noise: 0.5)
            case .commit:
                Recipe(start: 1400, end: 1400, peak: nil, duration: 0.030, level: 0.10, noise: 0.3)
            case .reject:
                Recipe(start: 320, end: 260, peak: nil, duration: 0.070, level: 0.12, noise: 0.2)

            case .beep:
                Recipe(start: 880, end: 880, peak: nil, duration: 0.09, level: 0.10,
                       decay: 4, square: 0.7)
            case .boop:
                Recipe(start: 700, end: 300, peak: nil, duration: 0.15, level: 0.11,
                       decay: 3.2, square: 0.5)
            case .bleep:
                Recipe(start: 380, end: 1020, peak: nil, duration: 0.12, level: 0.10,
                       decay: 3.4, square: 0.6)
            case .chirp:
                Recipe(start: 1200, end: 2300, peak: nil, duration: 0.07, level: 0.09, decay: 5)
            case .squeak:
                Recipe(start: 1500, end: 2500, peak: nil, duration: 0.11, level: 0.09,
                       vibrato: 130, vibratoRate: 24, decay: 4)
            case .meow:
                // Up, then down, with a wobble — the shape of the vowel rather
                // than any attempt at a real cat.
                Recipe(start: 430, end: 480, peak: 900, duration: 0.32, level: 0.13,
                       vibrato: 26, vibratoRate: 13, decay: 2.2, square: 0.35)
            case .purr:
                Recipe(start: 92, end: 78, peak: nil, duration: 0.30, level: 0.12,
                       vibrato: 22, vibratoRate: 32, decay: 1.6, square: 0.25)
            case .warble:
                Recipe(start: 660, end: 620, peak: nil, duration: 0.19, level: 0.10,
                       vibrato: 95, vibratoRate: 11, decay: 3, square: 0.3)
            case .blip:
                Recipe(start: 1800, end: 820, peak: nil, duration: 0.055, level: 0.09, decay: 6)
            }
        }
    }

    /// Whether the system makes any sound at all.
    ///
    /// A global rather than an environment read, because sound *is* global —
    /// there is one speaker, and a control has no more business asking whether
    /// it may use it than it has asking whether it may exist.
    ///
    /// Set it directly, or through `.glitchSound(isEnabled:volume:)`.
    public static var isEnabled = true {
        didSet { shared.applyVolume() }
    }

    /// How loud, `0` to `1`. Defaults deliberately low: this is punctuation,
    /// not content.
    public static var volume: Double = 0.6 {
        didSet { shared.applyVolume() }
    }

    /// Set by `.glitchDelight(false)`.
    ///
    /// Kept separate from `isEnabled` so the two switches compose the only way
    /// that makes sense: turning the game-feel layer off silences everything,
    /// but turning it back on restores whatever sound preference the person
    /// actually chose rather than forcing sound on. Delight can quieten the
    /// system; it can't make it speak.
    public static var isSuppressed = false

    private init() {}

    // MARK: - Public

    /// Traversal: a notch crossed, a selection moved, a step taken. Fires
    /// often, so it is the quietest of the three.
    public static func tick() { shared.play(.tick) }
    /// Something committed: a value landed, a button fired, a menu chose.
    public static func commit() { shared.play(.commit) }
    /// Something refused: a limit reached, a value out of range.
    public static func reject() { shared.play(.reject) }

    /// A random noise, for something poked rather than operated.
    ///
    /// Never the same one twice running: a random pick that repeats reads as a
    /// single sound misfiring, which is the opposite of playful.
    ///
    /// - Returns: the name of the noise made — "boop", "meow" — so a caller
    ///   can put it on screen, or `nil` when the system is silent. Callers get
    ///   to show the word exactly when there was a sound to name it after.
    @discardableResult
    public static func playful() -> String? { shared.playRandom() }

    // MARK: - Engine

    private func applyVolume() {
        player.volume = Float(max(0, min(Self.volume, 1)))
    }

    private var canPlay: Bool {
        Self.isEnabled && !Self.isSuppressed && Self.volume > 0
    }

    private func play(_ voice: Voice) {
        guard canPlay else { return }
        prepareIfNeeded()
        guard isReady, let variants = buffers[voice], !variants.isEmpty else { return }

        // A random variant, never the same one twice running — repetition is
        // what the variants exist to break.
        var index = Int.random(in: 0..<variants.count)
        if variants.count > 1, index == lastVariant[voice] {
            index = (index + 1) % variants.count
        }
        lastVariant[voice] = index

        // `.interrupts` rather than queueing: during a fast drag the ticks
        // would otherwise pile into a buzz.
        player.scheduleBuffer(variants[index], at: nil, options: [.interrupts])
        if !player.isPlaying { player.play() }
    }

    private func playRandom() -> String? {
        // Checked before picking, so a silent system doesn't consume a voice
        // and report a name for a sound nobody heard.
        guard canPlay else { return nil }

        let choices = Voice.playful.filter { $0 != lastPlayful }
        guard let voice = choices.randomElement() else { return nil }
        lastPlayful = voice
        play(voice)
        return voice.name
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

        for voice in Voice.allCases {
            // The working voices fire constantly, so they get the pitch
            // spread; the playful ones are already varied by being nine
            // different sounds.
            let rates: [Double] = switch voice {
            case .tick, .commit: [0.94, 0.97, 1.0, 1.03, 1.06]
            default: [1.0]
            }
            buffers[voice] = rates.compactMap {
                Self.render(voice.recipe.pitched(by: $0), format: format)
            }
        }

        do {
            try engine.start()
            applyVolume()
            isReady = true
        } catch {
            // No audio route, no permission, no problem — everything else
            // about the control still works.
            didFail = true
        }
    }

    /// Renders a recipe to samples.
    ///
    /// The phase is integrated rather than computed from `sin(2πft)`, because
    /// with a moving frequency the second form is wrong — it jumps the phase
    /// every time the pitch changes, and a sweep built that way clicks its way
    /// up the scale instead of gliding.
    /// Scales every rendered voice above the level the recipes were authored
    /// at, matching the Glitch Sound FX library's convention: boost until the
    /// loudest voice lands just under the peak ceiling. The loudest recipe
    /// (`meow`, level 0.13) × 5.5 sits just below 0.72, which is the same
    /// ceiling that library limits to — so at equal volume settings the two
    /// systems speak at the same level.
    nonisolated static let outputBoost: Float = 5.5
    /// The most any rendered sample may reach, after the boost.
    nonisolated static let peakCeiling: Float = 0.72

    nonisolated static func render(
        _ recipe: Recipe,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * recipe.duration)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0]
        else { return nil }

        buffer.frameLength = frames
        let decay = recipe.decay / recipe.duration
        // A couple of milliseconds of fade-in. Without it every sound starts
        // on a discontinuity, which is audible as a tick in front of the note.
        let attackDuration = min(0.002, recipe.duration * 0.2)
        var phase = 0.0

        for frame in 0..<Int(frames) {
            let t = Double(frame) / sampleRate
            let progress = t / recipe.duration

            // Straight sweep, or up to a peak and back down.
            var frequency: Double
            if let peak = recipe.peak {
                frequency = progress < 0.5
                    ? recipe.start + (peak - recipe.start) * (progress * 2)
                    : peak + (recipe.end - peak) * ((progress - 0.5) * 2)
            } else {
                frequency = recipe.start + (recipe.end - recipe.start) * progress
            }
            if recipe.vibrato > 0 {
                frequency += sin(2 * .pi * recipe.vibratoRate * t) * recipe.vibrato
            }

            phase += 2 * .pi * frequency / sampleRate
            let sine = sin(phase)
            let squared = sine >= 0 ? 0.6 : -0.6
            let tone = sine * (1 - recipe.square) + squared * recipe.square

            let attack = t < attackDuration ? t / attackDuration : 1
            let noise = t < 0.001 ? Double.random(in: -0.5...0.5) * recipe.noise : 0
            let envelope = exp(-decay * t) * attack

            channel[frame] = Float((tone + noise) * envelope) * recipe.level
        }

        // Boosted after synthesis, and limited per buffer rather than trusting
        // the levels: a retuned recipe must never be able to clip.
        var peak: Float = 0
        for frame in 0..<Int(frames) {
            peak = max(peak, abs(channel[frame]))
        }
        let boosted = peak * outputBoost
        let gain = boosted > peakCeiling ? peakCeiling / peak : outputBoost
        for frame in 0..<Int(frames) {
            channel[frame] *= gain
        }
        return buffer
    }
}
