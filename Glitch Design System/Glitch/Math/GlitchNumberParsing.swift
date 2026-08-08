import Foundation

/// Text ↔ number conversion for controls that let you type a value.
///
/// Parsing is deliberately forgiving: someone editing a drag field types
/// quickly and often leaves a unit behind ("12px"). Rejecting that input and
/// snapping back to the old value feels broken, so we take the leading number
/// and ignore the rest. Only genuinely numberless input falls back.
public enum GlitchNumberParsing {

    /// The leading number in `text`, or `fallback` when there isn't one.
    public static func parse(_ text: String, fallback: Double) -> Double {
        var digits = ""
        var hasDecimalPoint = false
        var hasDigit = false

        for character in text.trimmingCharacters(in: .whitespacesAndNewlines) {
            if character.isNumber {
                hasDigit = true
                digits.append(character)
            } else if character == "." && !hasDecimalPoint {
                hasDecimalPoint = true
                digits.append(character)
            } else if character == "-" && digits.isEmpty {
                digits.append(character)
            } else if character == "+" && digits.isEmpty {
                continue    // a leading plus is redundant, not an error
            } else {
                break
            }
        }

        guard hasDigit, let value = Double(digits) else { return fallback }
        return value
    }

    /// `value` rendered with exactly `decimals` fractional digits.
    public static func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(max(0, decimals))f", value)
    }
}
