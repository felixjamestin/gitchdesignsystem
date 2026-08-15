import SwiftUI

#if os(macOS)
import AppKit
#endif

private enum GooLabPreview: String, CaseIterable, Hashable, Identifiable {
    case field
    case radial
    case compare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .field: "Field"
        case .radial: "Radial"
        case .compare: "Compare"
        }
    }
}

/// A fixed test stage and a scrolling inspector for the Goo effects.
struct GooLabView: View {
    @Environment(\.glitchTheme) private var theme

    @State private var containerWidth: CGFloat = 0
    @State private var preview = GooLabPreview.field
    @State private var previewIdentity = 0
    @State private var didCopy = false

    @State private var style = GlitchGooStyle.standard
    @State private var separation = 44.0
    @State private var motionScale = 1.0

    @State private var email = ""
    @State private var fieldTrigger = GlitchGooFieldTrigger.focus
    @State private var reach = 1.55
    @State private var fieldStyle = GlitchGooFieldStyle.standard

    @State private var menuSurface = PathMenuSurface.gooey
    @State private var spread = 1.0
    @State private var wholeAngle = 360.0
    @State private var rotationOffset = 0.0
    @State private var petalScale = 1.0
    @State private var triggerScale = 1.0
    @State private var staggerScale = 1.0
    @State private var bondsTrigger = true
    @State private var glassBlendSpacing = 18.0

    private let menuItems = [
        PathMenuItem(title: "Flow", systemImage: "wind"),
        PathMenuItem(title: "Echo", systemImage: "waveform.path.ecg"),
        PathMenuItem(title: "Noise", systemImage: "aqi.medium"),
        PathMenuItem(title: "Warp", systemImage: "tornado"),
    ]

    private var isWide: Bool { containerWidth >= 820 }

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: 16) {
                    stage
                    inspector
                        .frame(width: 360)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        stage
                            .frame(height: 460)
                        inspectorContent
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.never)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
    }

    // MARK: - Fixed stage

    private var stage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Goo Lab")
                        .font(GlitchType.title(theme))
                        .foregroundStyle(theme.palette.textPrimary)
                    Text("Change a value. The active preview updates at once.")
                        .font(.system(size: theme.metrics.labelSize))
                        .foregroundStyle(theme.palette.labelSecondary)
                }
                Spacer(minLength: 8)
                rendererStatus
            }

            GlitchSegmented(
                selection: $preview,
                options: GooLabPreview.allCases.map { GlitchOption($0.title, value: $0) }
            )

            previewSurface
                .id(previewIdentity)
                .glitchGooStyle(style)
                .glitchGooFieldStyle(fieldStyle)
                .glitchMotion(scale: motionScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                        .strokeBorder(theme.palette.stroke, lineWidth: 1)
                }

            HStack(spacing: 8) {
                GlitchButton("Reset preview", systemImage: "arrow.counterclockwise") {
                    previewIdentity += 1
                }
                GlitchButton(
                    didCopy ? "Copied" : "Copy settings",
                    systemImage: didCopy ? "checkmark" : "doc.on.doc"
                ) {
                    copySettings()
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                .fill(theme.palette.panel)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.panelRadius, style: .continuous)
                .strokeBorder(theme.palette.stroke, lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rendererStatus: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(GlitchShaderLibrary.isAvailable ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(GlitchShaderLibrary.isAvailable ? "Metal SDF ready" : "Plain fallback")
                .font(.system(size: theme.metrics.labelSize, weight: .medium))
                .foregroundStyle(theme.palette.labelSecondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(theme.palette.track, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var previewSurface: some View {
        switch preview {
        case .field:
            fieldPreview
        case .radial:
            radialPreview
        case .compare:
            comparisonPreview
        }
    }

    private var fieldPreview: some View {
        VStack(spacing: 18) {
            GlitchGooField(
                text: $email,
                placeholder: "Enter your email",
                trigger: fieldTrigger,
                reach: CGFloat(reach)
            )
            Text(fieldHelp)
                .font(.system(size: theme.metrics.labelSize))
                .foregroundStyle(theme.palette.labelSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(24)
    }

    private var radialPreview: some View {
        VStack(spacing: 14) {
            GlitchPathMenu(
                items: menuItems,
                surface: menuSurface,
                spread: CGFloat(spread),
                wholeAngle: .degrees(wholeAngle),
                rotationOffset: .degrees(rotationOffset),
                petalScale: CGFloat(petalScale),
                triggerScale: CGFloat(triggerScale),
                staggerScale: staggerScale,
                bondsTrigger: bondsTrigger,
                glassBlendSpacing: CGFloat(glassBlendSpacing)
            ) { _ in }
            .frame(width: 340, height: 340)

            Text("Select the plus button. You can also press it and drag to an item.")
                .font(.system(size: theme.metrics.labelSize))
                .foregroundStyle(theme.palette.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }

    private var comparisonPreview: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(GlitchGooRenderer.allCases) { renderer in
                    VStack(spacing: 2) {
                        Text(renderer.title)
                            .font(.system(size: theme.metrics.labelSize, weight: .medium))
                            .foregroundStyle(theme.palette.labelSecondary)
                        GlitchGooLayer(
                            shapes: pair,
                            style: styled(as: renderer),
                            fill: theme.palette.trackActive,
                            size: CGSize(width: 160, height: 110)
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Use Separation to compare the bridge and the break point.")
                .font(.system(size: theme.metrics.labelSize))
                .foregroundStyle(theme.palette.labelSecondary)
        }
        .padding(20)
    }

    private var fieldHelp: String {
        switch fieldTrigger {
        case .focus: "Select the field to move the action button."
        case .nonEmpty: "Enter text to move the action button."
        case .always: "The action button stays separate in this mode."
        }
    }

    // MARK: - Inspector

    private var inspector: some View {
        ScrollView {
            inspectorContent
        }
        .scrollIndicators(.never)
    }

    private var inspectorContent: some View {
        GlitchPanel {
            GlitchSection("Presets") {
                HStack(spacing: 8) {
                    GlitchButton("Tight") { apply(.tight) }
                    GlitchButton("Standard") { apply(.standard) }
                    GlitchButton("Loose") { apply(.loose) }
                }
                GlitchButton("Reset all", systemImage: "arrow.counterclockwise", action: resetAll)
            }

            GlitchDivider()

            switch preview {
            case .field:
                fieldControls
            case .radial:
                radialControls
            case .compare:
                comparisonControls
            }

            GlitchDivider()
            rendererControls
            GlitchDivider()
            motionControls
        }
    }

    private var fieldControls: some View {
        GlitchSection("Field") {
            GlitchSelect(
                "Trigger",
                selection: $fieldTrigger,
                options: GlitchGooFieldTrigger.allCases.map { GlitchOption($0.title, value: $0) }
            )
            GlitchSlider("Reach", value: reachBinding, in: 0.6 ... 2.2, step: 0.05)
            GlitchSlider("Reserved space", value: fieldBinding(\.reservedReach), in: 0.8 ... 2.6, step: 0.05)
            GlitchSlider("Field width", value: fieldBinding(\.width), in: 180 ... 360, step: 2)
            GlitchSlider("Field height", value: fieldBinding(\.heightScale), in: 0.8 ... 1.6, step: 0.05)
            GlitchSlider("Button size", value: fieldBinding(\.buttonScale), in: 0.7 ... 1.4, step: 0.05)
            GlitchSlider("Icon blur", value: fieldBinding(\.iconBlur), in: 0 ... 12, step: 0.5)
            GlitchSlider("Icon delay", value: $fieldStyle.iconRevealDelay, in: 0 ... 0.3, step: 0.01)
            GlitchSlider("Hover lift", value: fieldBinding(\.hoverScale), in: 1 ... 1.04, step: 0.002)
            GlitchToggle("Dismiss after submit", isOn: $fieldStyle.dismissesOnSubmit)
            explain("Reserved space keeps nearby controls still. If Reach is larger, the field adds the space that it needs.")
        }
    }

    private var radialControls: some View {
        GlitchSection("Radial menu") {
            GlitchSelect(
                "Surface",
                selection: $menuSurface,
                options: PathMenuSurface.allCases.map { GlitchOption($0.title, value: $0) }
            )
            GlitchSlider("Spread", value: $spread, in: 0.55 ... 1.6, step: 0.05)
            GlitchSlider("Arc", value: $wholeAngle, in: 60 ... 360, step: 15)
            GlitchSlider("Rotation", value: $rotationOffset, in: -180 ... 180, step: 5)
            GlitchSlider("Petal size", value: $petalScale, in: 0.7 ... 1.5, step: 0.05)
            GlitchSlider("Trigger size", value: $triggerScale, in: 0.7 ... 1.5, step: 0.05)
            GlitchSlider("Stagger", value: $staggerScale, in: 0 ... 2.5, step: 0.1)
            if menuSurface == .gooey {
                GlitchToggle("Bond to trigger", isOn: $bondsTrigger)
            }
            if menuSurface.isGlass {
                GlitchSlider("Glass merge", value: $glassBlendSpacing, in: 0 ... 72, step: 2)
            }
            explain("Spread changes travel distance. Arc and Rotation change the fan direction. Goo uses one shared body.")
        }
    }

    private var comparisonControls: some View {
        GlitchSection("Comparison") {
            GlitchSlider("Separation", value: $separation, in: 0 ... 160, step: 2)
            explain("Distance Field has a stable bridge. Blur uses an offscreen image. Plain draws only the shape union.")
        }
    }

    private var rendererControls: some View {
        GlitchSection("Renderer") {
            GlitchSelect(
                "Method",
                selection: $style.renderer,
                options: GlitchGooRenderer.allCases.map { GlitchOption($0.title, value: $0) }
            )

            if style.renderer != .plain {
                GlitchSlider("Blend", value: gooBinding(\.blend), in: 0 ... 48, step: 0.5)
            }
            if style.renderer == .blurThreshold {
                GlitchSlider("Crispness", value: $style.crispness, in: 2 ... 60, step: 1)
            }
            if style.renderer == .sdf {
                GlitchSlider("Edge softness", value: gooBinding(\.edgeSoftness), in: 0.2 ... 4, step: 0.1)
                GlitchSlider("Rim width", value: gooBinding(\.rimWidth), in: 0 ... 6, step: 0.1)
                GlitchSlider("Rim opacity", value: $style.rimOpacity, in: 0 ... 1, step: 0.01)
                GlitchSlider("Lit edge", value: $style.rimSecondaryOpacity, in: 0 ... 1, step: 0.01)
                GlitchSlider("Wobble", value: gooBinding(\.wobble), in: 0 ... 6, step: 0.1)
                if style.wobble > 0 {
                    GlitchSlider("Wobble speed", value: $style.wobbleSpeed, in: 0.2 ... 4, step: 0.1)
                }
            }

            GlitchSlider("Shadow radius", value: gooBinding(\.shadowRadius), in: 0 ... 24, step: 0.5)
            GlitchSlider("Shadow opacity", value: $style.shadowOpacity, in: 0 ... 1, step: 0.01)
            explain(rendererHelp)
        }
    }

    private var motionControls: some View {
        GlitchSection("Motion") {
            GlitchSlider("Time scale", value: $motionScale, in: 0.25 ... 2.5, step: 0.05)
            explain("This value changes the preview motion. It does not change the Goo shape.")
        }
    }

    private var rendererHelp: String {
        switch style.renderer {
        case .sdf:
            "Use Distance Field for circles and capsules. It is one Metal pass and gives direct edge and light controls."
        case .blurThreshold:
            "Use Blur only when the Goo must merge an arbitrary view. It needs an offscreen image and a Gaussian blur."
        case .plain:
            "Plain keeps all controls usable. It does not merge the shapes."
        }
    }

    private func explain(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.metrics.labelSize))
            .foregroundStyle(theme.palette.labelSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Values and actions

    private var pair: [GlitchGooShape] {
        [
            .circle(center: CGPoint(x: -separation / 2, y: 0), diameter: 56),
            .circle(center: CGPoint(x: separation / 2, y: 0), diameter: 44),
        ]
    }

    private func styled(as renderer: GlitchGooRenderer) -> GlitchGooStyle {
        var copy = style
        copy.renderer = renderer
        return copy
    }

    private func apply(_ preset: GlitchGooStyle) {
        style = preset
        didCopy = false
    }

    private func resetAll() {
        style = .standard
        separation = 44
        motionScale = 1
        email = ""
        fieldTrigger = .focus
        reach = 1.55
        fieldStyle = .standard
        menuSurface = .gooey
        spread = 1
        wholeAngle = 360
        rotationOffset = 0
        petalScale = 1
        triggerScale = 1
        staggerScale = 1
        bondsTrigger = true
        glassBlendSpacing = 18
        previewIdentity += 1
        didCopy = false
    }

    private func copySettings() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(configurationText, forType: .string)
        #endif
        didCopy = true
    }

    private var configurationText: String {
        """
        Goo renderer: \(style.renderer.title)
        Blend: \(formatted(style.blend))
        Edge softness: \(formatted(style.edgeSoftness))
        Shadow: \(formatted(style.shadowRadius)) / \(formatted(style.shadowOpacity))
        Field trigger: \(fieldTrigger.title)
        Field reach: \(formatted(reach))
        Radial surface: \(menuSurface.title)
        Radial spread: \(formatted(spread))
        Radial arc: \(formatted(wholeAngle)) degrees
        Radial rotation: \(formatted(rotationOffset)) degrees
        """
    }

    private func formatted<T: BinaryFloatingPoint>(_ value: T) -> String {
        String(format: "%.2f", Double(value))
    }

    private var reachBinding: Binding<Double> {
        Binding(
            get: { reach },
            set: { value in
                reach = value
                fieldStyle.reservedReach = max(fieldStyle.reservedReach, CGFloat(value))
                didCopy = false
            }
        )
    }

    private func gooBinding(_ keyPath: WritableKeyPath<GlitchGooStyle, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(style[keyPath: keyPath]) },
            set: { style[keyPath: keyPath] = CGFloat($0); didCopy = false }
        )
    }

    private func fieldBinding(_ keyPath: WritableKeyPath<GlitchGooFieldStyle, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(fieldStyle[keyPath: keyPath]) },
            set: { fieldStyle[keyPath: keyPath] = CGFloat($0); didCopy = false }
        )
    }
}

#Preview {
    GooLabView()
        .frame(width: 1040, height: 760)
        .background(GlitchPalette.dark.background)
        .glitchTheme()
        .glitchMotion()
        .preferredColorScheme(.dark)
}
