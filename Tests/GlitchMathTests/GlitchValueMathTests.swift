import Testing
import GlitchMath

@Suite("Value math")
struct GlitchValueMathTests {

    // MARK: - Clamping

    @Test("clamps below the range, above the range, and passes values through")
    func clamping() {
        #expect(GlitchValueMath.clamp(-5, to: 0...10) == 0)
        #expect(GlitchValueMath.clamp(15, to: 0...10) == 10)
        #expect(GlitchValueMath.clamp(4, to: 0...10) == 4)
    }

    // MARK: - Normalizing

    @Test("normalize maps the range endpoints to 0 and 1")
    func normalizeEndpoints() {
        #expect(GlitchValueMath.normalize(0, in: 0...10) == 0)
        #expect(GlitchValueMath.normalize(10, in: 0...10) == 1)
        #expect(GlitchValueMath.normalize(2.5, in: 0...10) == 0.25)
    }

    @Test("normalize clamps values outside the range")
    func normalizeClamps() {
        #expect(GlitchValueMath.normalize(-100, in: 0...10) == 0)
        #expect(GlitchValueMath.normalize(100, in: 0...10) == 1)
    }

    /// A zero-width range is the classic custom-slider divide-by-zero crash.
    @Test("normalize on a degenerate range returns 1 rather than NaN")
    func normalizeDegenerateRange() {
        let t = GlitchValueMath.normalize(5, in: 5...5)
        #expect(!t.isNaN)
        #expect(t == 1)
    }

    @Test("denormalize inverts normalize across the range")
    func denormalizeRoundTrips() {
        let range = -20.0...60.0
        for value in [-20.0, 0.0, 13.5, 60.0] {
            let round = GlitchValueMath.denormalize(
                GlitchValueMath.normalize(value, in: range), in: range
            )
            #expect(abs(round - value) < 1e-9)
        }
    }

    // MARK: - Hit-testing a drag

    @Test("fraction of x across a zero width is 0, not NaN")
    func fractionZeroWidth() {
        let f = GlitchValueMath.fraction(ofX: 12, width: 0)
        #expect(!f.isNaN)
        #expect(f == 0)
    }

    @Test("fraction of x is clamped to 0...1")
    func fractionClamped() {
        #expect(GlitchValueMath.fraction(ofX: -30, width: 100) == 0)
        #expect(GlitchValueMath.fraction(ofX: 150, width: 100) == 1)
        #expect(GlitchValueMath.fraction(ofX: 25, width: 100) == 0.25)
    }

    // MARK: - Stepping

    @Test("snap rounds to the nearest step")
    func snapRoundsToNearest() {
        #expect(GlitchValueMath.snap(7.4, step: 5, in: 0...100) == 5)
        #expect(GlitchValueMath.snap(7.6, step: 5, in: 0...100) == 10)
    }

    @Test("snap measures steps from the range's lower bound")
    func snapIsRelativeToLowerBound() {
        #expect(GlitchValueMath.snap(7, step: 5, in: 1...100) == 6)
    }

    @Test("snap never leaves the range, even when a step would")
    func snapStaysInRange() {
        #expect(GlitchValueMath.snap(99, step: 10, in: 0...95) == 95)
    }

    @Test("snap with a non-positive step only clamps")
    func snapWithoutStep() {
        #expect(GlitchValueMath.snap(7.37, step: 0, in: 0...10) == 7.37)
        #expect(GlitchValueMath.snap(-1, step: 0, in: 0...10) == 0)
    }

    // MARK: - Rubber banding

    @Test("rubber band resists: zero at rest, monotonic, and always less than the input")
    func rubberBandResists() {
        #expect(GlitchValueMath.rubberBand(0, dimension: 100) == 0)

        let small = GlitchValueMath.rubberBand(10, dimension: 100)
        let large = GlitchValueMath.rubberBand(50, dimension: 100)

        #expect(small > 0)
        #expect(large > small)
        #expect(small < 10)
        #expect(large < 50)
    }

    @Test("rubber band resistance increases with distance")
    func rubberBandIsSubLinear() {
        let small = GlitchValueMath.rubberBand(10, dimension: 100)
        let large = GlitchValueMath.rubberBand(50, dimension: 100)
        #expect(large / 50 < small / 10)
    }

    @Test("rubber band is symmetric about zero")
    func rubberBandSymmetric() {
        let positive = GlitchValueMath.rubberBand(30, dimension: 100)
        let negative = GlitchValueMath.rubberBand(-30, dimension: 100)
        #expect(negative == -positive)
    }

    @Test("rubber band across a zero dimension does not produce NaN")
    func rubberBandZeroDimension() {
        let r = GlitchValueMath.rubberBand(20, dimension: 0)
        #expect(!r.isNaN)
        #expect(r == 0)
    }
}
