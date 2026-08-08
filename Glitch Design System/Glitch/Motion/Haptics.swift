import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Physical feedback for discrete events.
///
/// One of only two places in the system permitted to branch on platform: there
/// is no cross-platform haptic API, and macOS has no equivalent for these
/// gestures. Calls compile away to nothing off iOS, so controls call these
/// freely without guarding.
@MainActor
public enum GlitchHaptics {

    /// Crossing a step while dragging. Light and low-intensity — this fires
    /// repeatedly during a drag and must not become noise.
    public static func tick() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.4)
        #endif
    }

    /// A discrete choice changed: a segment, a radio option, a menu item.
    public static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// A state committed: a toggle flipped, a button fired.
    public static func impact() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
        #endif
    }

    /// Hitting a limit — the end of a slider's travel.
    public static func limit() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
        #endif
    }
}
