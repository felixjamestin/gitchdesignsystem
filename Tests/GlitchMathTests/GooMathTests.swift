import CoreGraphics
import Testing
import GlitchDesignSystem

@Suite("Goo math")
struct GooMathTests {

    @Test("the smooth minimum never rises above the hard one")
    func neverExceedsMin() {
        for a in stride(from: -50.0, through: 50.0, by: 7.0) {
            for b in stride(from: -50.0, through: 50.0, by: 7.0) {
                #expect(glitchSmoothMin(a, b, k: 12) <= min(a, b) + 1e-9)
            }
        }
    }

    @Test("it does not care which shape is named first")
    func commutative() {
        #expect(abs(glitchSmoothMin(3, -8, k: 10) - glitchSmoothMin(-8, 3, k: 10)) < 1e-12)
    }

    /// The property that makes `blend` safe to animate to nothing: at zero it is
    /// exactly `min`, so the bridge disappears rather than degenerating.
    @Test("it collapses to the hard minimum as the blend vanishes")
    func collapsesToMin() {
        #expect(glitchSmoothMin(3, -8, k: 0) == -8)
        #expect(abs(glitchSmoothMin(3, -8, k: 1e-9) - (-8)) < 1e-6)
    }

    /// Shapes further apart than the blend width must not bond at all, or petals
    /// at rest would stay joined to a trigger they have long since left.
    @Test("shapes further apart than the blend do not bond")
    func noBondBeyondBlend() {
        #expect(glitchSmoothMin(0, 30, k: 10) == 0)
    }

    @Test("packing round-trips centre, size and radius")
    func packingRoundTrips() {
        let shapes = [
            GlitchGooShape.circle(center: CGPoint(x: 10, y: -4), diameter: 46),
            GlitchGooShape.capsule(center: .zero, size: CGSize(width: 200, height: 44)),
        ]
        let packed = GlitchGooPacking.pack(shapes)

        #expect(packed.count == shapes.count * GlitchGooPacking.stride)
        #expect(packed[0] == 10)
        #expect(packed[1] == -4)
        #expect(packed[2] == 23)
        #expect(packed[3] == 23)
        #expect(packed[4] == 23)
        #expect(packed[7] == 100)
        #expect(packed[8] == 22)
        #expect(packed[9] == 22)
    }

    /// More petals than the kernel declares room for is a visual compromise —
    /// the extras stop merging — rather than a buffer overrun.
    @Test("packing clamps to the kernel's capacity")
    func packingClamps() {
        let many = Array(
            repeating: GlitchGooShape.circle(center: .zero, diameter: 10),
            count: GlitchGooPacking.capacity + 24
        )
        #expect(GlitchGooPacking.pack(many).count == GlitchGooPacking.capacity * GlitchGooPacking.stride)
    }

    @Test("a circle is a capsule whose sides have closed up")
    func circleIsRoundCapsule() {
        let circle = GlitchGooShape.circle(center: .zero, diameter: 40)
        #expect(circle.cornerRadius == 20)
        #expect(circle.size == CGSize(width: 40, height: 40))
    }
}
