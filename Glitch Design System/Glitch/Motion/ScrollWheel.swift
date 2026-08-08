import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Scroll-wheel and two-finger-scroll adjustment for controls under the pointer.
///
/// The second and last place in the system that branches on platform. SwiftUI
/// has no scroll-wheel event, so macOS goes through a local event monitor
/// rather than a hosted `NSView`: a view in the hierarchy would either swallow
/// clicks or, if it declined hit-testing, never receive scroll events at all.
///
/// The monitor is installed only while the control is hovered, and consumes the
/// event so an enclosing scroll view doesn't scroll at the same time.
private struct GlitchScrollWheel: ViewModifier {
    var isActive: Bool
    var onScroll: (CGFloat) -> Void

    #if os(macOS)
    @State private var monitor: Any?
    #endif

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onChange(of: isActive, initial: true) { _, active in
                if active {
                    install()
                } else {
                    remove()
                }
            }
            .onDisappear { remove() }
        #else
        content
        #endif
    }

    #if os(macOS)
    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.scrollingDeltaX
            guard delta != 0 else { return event }
            onScroll(delta)
            return nil
        }
    }

    private func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
    #endif
}

extension View {
    /// Adjusts on scroll while `isActive` — typically bound to hover state.
    /// A no-op where there is no scroll wheel.
    public func glitchScrollWheel(
        isActive: Bool,
        _ onScroll: @escaping (CGFloat) -> Void
    ) -> some View {
        modifier(GlitchScrollWheel(isActive: isActive, onScroll: onScroll))
    }
}
