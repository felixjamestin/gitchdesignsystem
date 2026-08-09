import Testing
import Glitch

@Suite("Angle math")
struct GlitchAngleMathTests {

    private let sweep = GlitchAngleMath.defaultSweep   // 270°, the usual knob arc
    private let range = 0.0...100.0

    @Test("the arc's start and end map to the range's bounds")
    func endpointsMap() {
        #expect(GlitchAngleMath.value(forAngle: -sweep / 2, sweep: sweep, in: range) == 0)
        #expect(GlitchAngleMath.value(forAngle: sweep / 2, sweep: sweep, in: range) == 100)
    }

    @Test("the arc's midpoint is the range's midpoint")
    func midpointMaps() {
        #expect(abs(GlitchAngleMath.value(forAngle: 0, sweep: sweep, in: range) - 50) < 1e-9)
    }

    @Test("value and angle round-trip")
    func roundTrips() {
        for value in [0.0, 12.5, 50.0, 87.3, 100.0] {
            let angle = GlitchAngleMath.angle(forValue: value, sweep: sweep, in: range)
            let back = GlitchAngleMath.value(forAngle: angle, sweep: sweep, in: range)
            #expect(abs(back - value) < 1e-9)
        }
    }

    @Test("angles beyond the arc clamp to the bounds rather than wrapping around")
    func beyondArcClamps() {
        #expect(GlitchAngleMath.value(forAngle: -sweep, sweep: sweep, in: range) == 0)
        #expect(GlitchAngleMath.value(forAngle: sweep, sweep: sweep, in: range) == 100)
    }

    @Test("a zero sweep does not divide by zero")
    func degenerateSweep() {
        let v = GlitchAngleMath.value(forAngle: 1, sweep: 0, in: range)
        #expect(!v.isNaN)
    }

    // MARK: - Shortest delta

    @Test("shortest delta takes the direct route within a half turn")
    func directRoute() {
        #expect(abs(GlitchAngleMath.shortestDelta(from: 0, to: 1) - 1) < 1e-9)
        #expect(abs(GlitchAngleMath.shortestDelta(from: 1, to: 0) - -1) < 1e-9)
    }

    /// Without this, a knob dragged across the ±π seam jumps a full turn.
    @Test("shortest delta crosses the seam the short way, not the long way")
    func crossesSeam() {
        let almostPi = Double.pi - 0.1
        let justPastPi = -Double.pi + 0.1
        let delta = GlitchAngleMath.shortestDelta(from: almostPi, to: justPastPi)
        #expect(abs(delta - 0.2) < 1e-9)
    }

    @Test("shortest delta never exceeds a half turn in magnitude")
    func boundedByHalfTurn() {
        for (a, b) in [(0.0, 3.0), (3.0, 0.0), (-3.0, 3.0), (3.0, -3.0), (0.0, 6.0)] {
            #expect(abs(GlitchAngleMath.shortestDelta(from: a, to: b)) <= Double.pi + 1e-9)
        }
    }
}
