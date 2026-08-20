import SwiftUI

/// A type-erased `InsettableShape`.
///
/// SwiftUI ships `AnyShape` but nothing insettable, and the difference matters
/// here: `strokeBorder` — the modifier that keeps a hairline *inside* the
/// outline instead of straddling it — is only available on an insettable
/// shape. Erasing to `AnyShape` would mean stroking on the edge, and a bubble
/// whose border sits half outside it is a bubble half a point bigger than the
/// one its glass was clipped to.
///
/// Two closures rather than a stored existential, because `inset(by:)` is
/// generic in its return type and cannot be called through a box that has
/// forgotten which shape it holds.
public struct GlitchAnyInsettableShape: InsettableShape {
    private let makePath: (CGRect) -> Path
    private let makeInset: (CGFloat) -> GlitchAnyInsettableShape

    public init<S: InsettableShape>(_ shape: S) {
        makePath = { shape.path(in: $0) }
        makeInset = { GlitchAnyInsettableShape(shape.inset(by: $0)) }
    }

    public func path(in rect: CGRect) -> Path { makePath(rect) }

    public func inset(by amount: CGFloat) -> GlitchAnyInsettableShape { makeInset(amount) }
}
