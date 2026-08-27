import Testing
@testable import GlitchDesignSystem

@Suite("Sound floater flight")
struct SoundFloaterTests {
    @Test("the fade completes well before the climb does")
    func fadeEndsBeforeApogee() {
        // The word must be gone by ~60 % of the flight so it can never be
        // sliced by a container edge while still visible.
        #expect(SoundFloaterTiming.fadeEndFraction <= 0.65)
        #expect(SoundFloaterTiming.fadeEndFraction > 0)
    }

    @Test("the fade still leaves a readable beat before it starts")
    func fadeStartsAfterAReadableBeat() {
        #expect(SoundFloaterTiming.fadeDelayFraction >= 0.15)
    }

    @Test("random flights keep their randomness within the designed envelope")
    func randomFlightStaysInEnvelope() {
        for _ in 0..<200 {
            let floater = SoundFloater.random("boop")
            #expect(floater.rise >= -78 && floater.rise <= -46)
            #expect(floater.speed >= 0.85 && floater.speed <= 1.25)
            // Fade end in absolute seconds must undercut the flight duration
            // at every speed the roll can produce.
            let flight = SoundFloaterTiming.flightBase / floater.speed
            let fadeEnd = flight * SoundFloaterTiming.fadeEndFraction
            #expect(fadeEnd < flight)
        }
    }
}
