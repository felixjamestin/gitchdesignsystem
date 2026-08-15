import Testing
import GlitchDesignSystem

@Suite("Flick math")
struct GlitchFlickMathTests {

    @Test("velocity decays by the same fraction each second")
    func exponentialDecay() {
        let after1 = GlitchAngleMath.decayedVelocity(8, after: 1, friction: 2)
        let after2 = GlitchAngleMath.decayedVelocity(8, after: 2, friction: 2)
        // Exponential: the ratio between consecutive seconds is constant.
        #expect(abs(after2 / after1 - after1 / 8) < 1e-9)
    }

    @Test("zero time changes nothing, and direction is preserved")
    func identityAndSign() {
        #expect(GlitchAngleMath.decayedVelocity(5, after: 0, friction: 4) == 5)
        #expect(GlitchAngleMath.decayedVelocity(-5, after: 0.5, friction: 4) < 0)
    }

    @Test("a flick at the tuning's friction dies within a second")
    func diesQuickly() {
        let v = GlitchAngleMath.decayedVelocity(
            10,
            after: 1,
            friction: GlitchDelightTuning.flickFriction
        )
        #expect(abs(v) < GlitchDelightTuning.flickEngageVelocity)
    }
}
