import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Pointer shape as a statement of what a control does.
///
/// A drag field looks like a label until the cursor changes over it — the
/// cursor is the affordance. Kept here with the other platform-specific
/// interaction plumbing so control bodies stay platform-agnostic.
extension View {
    /// Shows the horizontal-resize cursor while `isActive`, indicating that
    /// this element scrubs. No-op where there is no cursor.
    public func glitchHorizontalScrubCursor(isActive: Bool) -> some View {
        #if os(macOS)
        return onChange(of: isActive) { _, active in
            if active {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        #else
        return self
        #endif
    }
}
