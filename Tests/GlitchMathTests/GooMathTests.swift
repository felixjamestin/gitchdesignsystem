import CoreGraphics
import Testing
import GlitchDesignSystem

@Suite("Goo math")
struct GooMathTests {

    // MARK: - Stadium distance

    @Test("a zero-length stadium is a circle")
    func circleDistance() {
        let c = CGPoint(x: 50, y: 50)
        #expect(GooMath.stadiumDistance(c, center: c, halfLength: 0, radius: 10) == -10)
        #expect(GooMath.stadiumDistance(CGPoint(x: 60, y: 50), center: c, halfLength: 0, radius: 10) == 0)
        #expect(GooMath.stadiumDistance(CGPoint(x: 75, y: 50), center: c, halfLength: 0, radius: 10) == 15)
    }

    @Test("distance above the stadium's straight section ignores the caps")
    func stadiumSide() {
        let d = GooMath.stadiumDistance(
            CGPoint(x: 50, y: 20),
            center: CGPoint(x: 50, y: 50), halfLength: 40, radius: 10
        )
        #expect(d == 20)   // 30 points above the axis, minus the radius
    }

    @Test("distance beyond the cap measures from the cap's centre")
    func stadiumCap() {
        // Cap centre sits at x = 90; the probe is 30 to its right.
        let d = GooMath.stadiumDistance(
            CGPoint(x: 120, y: 50),
            center: CGPoint(x: 50, y: 50), halfLength: 40, radius: 10
        )
        #expect(d == 20)
    }

    // MARK: - Smooth minimum

    @Test("smooth minimum is symmetric and never exceeds the plain minimum")
    func sminBasics() {
        #expect(GooMath.smoothMin(3, 7, k: 8) == GooMath.smoothMin(7, 3, k: 8))
        #expect(GooMath.smoothMin(3, 7, k: 8) <= 3)
    }

    @Test("zero smoothing is a hard union")
    func sminHard() {
        #expect(GooMath.smoothMin(3, 7, k: 0) == 3)
    }

    @Test("values further apart than k pass through untouched")
    func sminFar() {
        #expect(GooMath.smoothMin(3, 30, k: 8) == 3)
    }

    /// The property the whole effect rests on: between two nearby blobs the
    /// blended field dips below zero — a neck — where the hard union does not.
    @Test("smoothing forms a neck between nearby blobs")
    func sminNeck() {
        let a = CGPoint(x: 36, y: 50), b = CGPoint(x: 64, y: 50)
        let mid = CGPoint(x: 50, y: 50)
        let da = GooMath.stadiumDistance(mid, center: a, halfLength: 0, radius: 10)
        let db = GooMath.stadiumDistance(mid, center: b, halfLength: 0, radius: 10)
        #expect(min(da, db) > 0)                       // hard union: outside
        #expect(GooMath.smoothMin(da, db, k: 20) < 0)  // goo: inside the neck
    }

    // MARK: - Field blobs

    @Test("at progress 0 the button hides flush inside the capsule's end")
    func fieldMerged() {
        let blobs = GooMath.fieldBlobs(
            in: CGSize(width: 300, height: 40),
            buttonDiameter: 36, detachDistance: 16, progress: 0
        )
        let capsule = blobs[0], button = blobs[1]
        let capsuleRightEdge = capsule.center.x + capsule.halfLength + capsule.radius
        #expect(button.center.x + button.radius == capsuleRightEdge)
        // Fully contained: the union's silhouette is the capsule alone.
        #expect(button.radius <= capsule.radius)
    }

    @Test("at progress 1 the button has detached by the full gap and fills the footprint")
    func fieldDetached() {
        let width: CGFloat = 300
        let blobs = GooMath.fieldBlobs(
            in: CGSize(width: width, height: 40),
            buttonDiameter: 36, detachDistance: 16, progress: 1
        )
        let capsule = blobs[0], button = blobs[1]
        let capsuleRightEdge = capsule.center.x + capsule.halfLength + capsule.radius
        let gap = (button.center.x - button.radius) - capsuleRightEdge
        #expect(abs(gap - 16) < 0.001)
        #expect(abs((button.center.x + button.radius) - width) < 0.001)
    }

    @Test("the capsule never inverts when the control is narrow")
    func fieldNarrow() {
        let blobs = GooMath.fieldBlobs(
            in: CGSize(width: 60, height: 40),
            buttonDiameter: 36, detachDistance: 16, progress: 0.5
        )
        #expect(blobs[0].halfLength >= 0)
    }

    // MARK: - Menu delays

    @Test("petals leave first-to-last and return last-to-first")
    func menuDelays() {
        #expect(GooMath.menuDelay(index: 0, count: 5, stagger: 0.04, opening: true) == 0)
        #expect(GooMath.menuDelay(index: 2, count: 5, stagger: 0.04, opening: true) == 0.08)
        #expect(GooMath.menuDelay(index: 4, count: 5, stagger: 0.04, opening: false) == 0)
        #expect(GooMath.menuDelay(index: 0, count: 5, stagger: 0.04, opening: false) == 0.16)
    }
}
