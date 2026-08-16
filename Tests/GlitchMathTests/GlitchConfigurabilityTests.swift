import SwiftUI
import XCTest
@testable import GlitchDesignSystem

/// Construction tests for the per-instance appearance knobs: the point is
/// that the parameters exist with these names and types, and default to
/// today's behaviour. Rendering is judged by eye in the demo app.
@MainActor
final class GlitchConfigurabilityTests: XCTestCase {
    func testGrilleAcceptsFloaterAppearance() {
        _ = GlitchSoundGrille(
            "Output", isOn: true, volume: 50,
            floaterFontSize: 11,
            floaterTextColor: .orange,
            floaterBackground: .black.opacity(0.6))
    }
}
