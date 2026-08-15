import CoreGraphics
import Foundation

/// The polynomial smooth minimum — the whole of what "merging" means here.
///
/// `k` is the width of the blend, in the same units as the distances, so it
/// reads directly as how thick the bridge between two shapes is. That it is
/// independent of how soft their edges are is the reason for preferring a
/// distance field to a blur: blurring couples the two, and the reference this
/// is drawn from has to spend a second threshold pass recovering a hard edge it
/// blurred away in the first.
///
/// At `k == 0` this is exactly `min`, which is what makes the parameter safe to
/// animate down to nothing: the bridge thins and disappears rather than
/// degenerating into something that has to be special-cased.
///
/// Transcribed byte for byte into `GlitchGoo.metal`. It lives here as well so
/// the arithmetic can be tested on the CPU, where a failure names itself,
/// rather than inferred from a wrong picture.
public func glitchSmoothMin(_ a: Double, _ b: Double, k: Double) -> Double {
    guard k > 0 else { return min(a, b) }
    let h = max(k - abs(a - b), 0) / k
    return min(a, b) - h * h * k * 0.25
}

// MARK: - Packing

/// How shapes are laid out in the flat array the kernel reads.
///
/// Five floats each: centre x, centre y, half-width, half-height, corner radius.
public enum GlitchGooPacking {

    /// Floats per shape.
    public static let stride = 5

    /// The most shapes the kernel will merge, matching the loop bound declared
    /// in `GlitchGoo.metal`.
    ///
    /// Exceeding it is a visual compromise rather than a fault: `pack` drops the
    /// surplus, so a menu with more petals than this loses the merge on the
    /// extras and still draws every one of them. A silently truncated array is
    /// a far better failure than a buffer read past its end.
    public static let capacity = 16

    public static func pack(_ shapes: [GlitchGooShape]) -> [Float] {
        var packed = [Float]()
        packed.reserveCapacity(min(shapes.count, capacity) * stride)

        for shape in shapes.prefix(capacity) {
            packed.append(Float(shape.center.x))
            packed.append(Float(shape.center.y))
            packed.append(Float(shape.size.width / 2))
            packed.append(Float(shape.size.height / 2))
            packed.append(Float(shape.cornerRadius))
        }
        return packed
    }
}
