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

    /// A ramp is optional, and a grille without one is the grille that shipped.
    func testGrilleAcceptsColourRamp() {
        _ = GlitchSoundGrille(
            "Output", isOn: true, volume: 50,
            ramp: [.blue, .purple, .orange])
        _ = GlitchSoundGrille("Output", isOn: true, volume: 50)
    }

    func testSliderAcceptsEditingSwitch() {
        _ = GlitchSlider(
            "Volume", value: .constant(0.5), in: 0...1,
            allowsValueEditing: false)
    }

    /// The token ships unset in every density preset, so existing themes
    /// keep sizing the chevron from `iconSize` exactly as before.
    func testDisclosureSizeDefaultsToFollowingIconSize() {
        XCTAssertNil(GlitchMetrics.resolve(.compact, style: .film).disclosureSize)
        XCTAssertNil(GlitchMetrics.resolve(.comfortable, style: .glitch).disclosureSize)
    }

    /// One radius holds across every style and density; unset keeps each style's own.
    func testControlRadiusOverridesEveryStyle() {
        for style in GlitchThemeStyle.allCases {
            for density in GlitchDensity.allCases {
                XCTAssertEqual(
                    GlitchMetrics.resolve(density, style: style, controlRadius: 5).controlRadius, 5)
            }
        }
        XCTAssertEqual(GlitchMetrics.resolve(.compact, style: .engineering).controlRadius, 2)
        XCTAssertEqual(GlitchMetrics.resolve(.compact, style: .liquidGlass).controlRadius, 18)
        XCTAssertEqual(GlitchMetrics.resolve(.compact, style: .film, controlRadius: -4).controlRadius, 0)
    }
}
