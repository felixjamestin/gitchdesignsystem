import SwiftUI

/// One choice in a radio group, segmented control, or select.
///
/// Shared so the three controls are interchangeable at the call site: the same
/// array of options can be rendered as radios in a wide panel and as a select
/// in a narrow one, without restructuring the caller's data.
public struct GlitchOption<Value: Hashable>: Identifiable {
    public let value: Value
    public let title: String
    public let systemImage: String?

    public var id: Value { value }

    public init(_ title: String, value: Value, systemImage: String? = nil) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
    }
}

extension GlitchOption where Value == String {
    /// `["Linear", "Ease"]` → options whose value is their own title.
    public static func list(_ titles: [String]) -> [GlitchOption<String>] {
        titles.map { GlitchOption($0, value: $0) }
    }
}
