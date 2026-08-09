import Testing
import GlitchDesignSystem

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

    // MARK: - Track overscroll

    @Test("overscroll stays at zero until the pointer passes the dead zone")
    func overscrollDeadZone() {
        #expect(GlitchValueMath.trackOverscroll(pastEdge: 0) == 0)
        #expect(GlitchValueMath.trackOverscroll(pastEdge: 31) == 0)
        #expect(GlitchValueMath.trackOverscroll(pastEdge: 32) == 0)
    }

    @Test("overscroll follows a square root beyond the dead zone")
    func overscrollCurve() {
        // 50pt past the dead zone is a quarter of the ramp, so half the travel.
        #expect(abs(GlitchValueMath.trackOverscroll(pastEdge: 82) - 4) < 1e-9)
    }

    @Test("overscroll saturates at its maximum and never exceeds it")
    func overscrollSaturates() {
        #expect(abs(GlitchValueMath.trackOverscroll(pastEdge: 232) - 8) < 1e-9)
        #expect(GlitchValueMath.trackOverscroll(pastEdge: 5000) == 8)
    }

    @Test("overscroll is monotonic")
    func overscrollMonotonic() {
        var previous = -1.0
        for d in stride(from: 0.0, through: 300, by: 10) {
            let value = GlitchValueMath.trackOverscroll(pastEdge: d)
            #expect(value >= previous)
            previous = value
        }
    }

    // MARK: - Click snapping

    /// With ten or fewer steps every step gets its own tick, so a click is
    /// unambiguous and should land exactly on one.
    @Test("a click snaps to the nearest step when the range is coarse")
    func clickSnapsCoarseRange() {
        #expect(abs(GlitchValueMath.snapToClick(0.44, in: 0...1, step: 0.1) - 0.4) < 1e-9)
        #expect(abs(GlitchValueMath.snapToClick(0.46, in: 0...1, step: 0.1) - 0.5) < 1e-9)
    }

    @Test("a click near a tenth is pulled onto it")
    func clickSnapsNearTick() {
        // 42% is within 3.125% of the 40% tick.
        #expect(abs(GlitchValueMath.snapToClick(42, in: 0...100, step: 1) - 40) < 1e-9)
    }

    @Test("a click far from any tick lands exactly where it was made")
    func clickKeepsExactPosition() {
        // 44% is further than 3.125% from both 40% and 50%.
        #expect(abs(GlitchValueMath.snapToClick(44, in: 0...100, step: 1) - 44) < 1e-9)
    }

    @Test("clicking at either extreme reaches the bound exactly")
    func clickReachesBounds() {
        #expect(GlitchValueMath.snapToClick(0, in: 0...100, step: 1) == 0)
        #expect(GlitchValueMath.snapToClick(100, in: 0...100, step: 1) == 100)
    }

    @Test("click snapping on a degenerate range does not produce NaN")
    func clickSnapDegenerate() {
        let v = GlitchValueMath.snapToClick(5, in: 5...5, step: 1)
        #expect(!v.isNaN)
        #expect(v == 5)
    }

    // MARK: - Notches

    @Test("a fine range gets nine notches at every tenth")
    func notchesForFineRange() {
        let fractions = GlitchValueMath.notchFractions(in: 0...100, step: 1)
        #expect(fractions.count == 9)
        #expect(abs(fractions.first! - 0.1) < 1e-9)
        #expect(abs(fractions.last! - 0.9) < 1e-9)
    }

    @Test("a coarse range gets one notch per step")
    func notchesForCoarseRange() {
        let fractions = GlitchValueMath.notchFractions(in: 0...4, step: 1)
        #expect(fractions.count == 3)
        #expect(abs(fractions[0] - 0.25) < 1e-9)
        #expect(abs(fractions[1] - 0.50) < 1e-9)
        #expect(abs(fractions[2] - 0.75) < 1e-9)
    }

    @Test("notches exclude the bounds, which are drawn by the track's own ends")
    func notchesExcludeBounds() {
        let fractions = GlitchValueMath.notchFractions(in: 0...1, step: 0.1)
        #expect(!fractions.contains { $0 <= 0 || $0 >= 1 })
    }

    @Test("a degenerate range has no notches")
    func notchesDegenerate() {
        #expect(GlitchValueMath.notchFractions(in: 5...5, step: 1).isEmpty)
    }

    @Test("the nearest notch includes both bounds")
    func nearestNotchIncludesBounds() {
        #expect(GlitchValueMath.nearestNotch(to: 3, in: 0...100, step: 1) == 0)
        #expect(GlitchValueMath.nearestNotch(to: 97, in: 0...100, step: 1) == 100)
    }

    @Test("the nearest notch is the closest tenth for a fine range")
    func nearestNotchFineRange() {
        #expect(abs(GlitchValueMath.nearestNotch(to: 42, in: 0...100, step: 1) - 40) < 1e-9)
        #expect(abs(GlitchValueMath.nearestNotch(to: 46, in: 0...100, step: 1) - 50) < 1e-9)
    }

    @Test("magnetism pulls a value onto a notch only within its tolerance")
    func magnetismRespectsTolerance() {
        // 42% is 2% from the 40% notch, inside a 3% pull.
        #expect(abs(GlitchValueMath.magnetize(42, in: 0...100, step: 1, tolerance: 0.03) - 40) < 1e-9)
        // 45% is 5% away, outside it, and must be left alone.
        #expect(abs(GlitchValueMath.magnetize(45, in: 0...100, step: 1, tolerance: 0.03) - 45) < 1e-9)
    }

    @Test("a zero tolerance never pulls")
    func magnetismZeroTolerance() {
        #expect(abs(GlitchValueMath.magnetize(42, in: 0...100, step: 1, tolerance: 0) - 42) < 1e-9)
    }

    @Test("magnetism keeps the value inside the range")
    func magnetismClamps() {
        #expect(GlitchValueMath.magnetize(-10, in: 0...100, step: 1, tolerance: 0.03) == 0)
        #expect(GlitchValueMath.magnetize(150, in: 0...100, step: 1, tolerance: 0.03) == 100)
    }
}
