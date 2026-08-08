import SwiftUI

/// The parameters the playground panel drives.
struct CanvasParameters {
    var flow: Double = 73
    var elasticity: Double = 37
    var noise: Double = 6
    var speed: Double = 5
    var echoes: Double = 68
    var tension: Double = 24
    var clump: Double = 0
    var variation: Double = 10
    var stroke: Double = 6

    var colorIndex: Int = 0
    var isPlaying: Bool = true
    var mirrored: Bool = false
    var strandCount: Double = 14
}

/// A flow field of strands, drawn entirely from the panel's parameters.
///
/// Stateless by construction: every frame is a pure function of the elapsed
/// time and the parameter values, so dragging a slider changes the drawing on
/// the very next frame with nothing to settle or catch up.
struct GlitchCanvas: View {
    let parameters: CanvasParameters
    let color: Color

    private let segments = 90

    var body: some View {
        TimelineView(.animation(paused: !parameters.isPlaying)) { timeline in
            Canvas { context, size in
                draw(
                    in: &context,
                    size: size,
                    time: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .accessibilityLabel("Animated preview")
        .accessibilityValue(
            parameters.isPlaying ? "Playing" : "Paused"
        )
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0, size.height > 0 else { return }

        let strands = max(1, Int(parameters.strandCount))
        let amplitude = parameters.flow / 100 * size.height * 0.34
        let frequency = 0.6 + parameters.tension / 100 * 5
        let speed = parameters.speed / 100 * 3
        let noiseAmount = parameters.noise / 100 * size.height * 0.09
        let envelopeExponent = 0.3 + parameters.elasticity / 100 * 2.2
        let echoCount = Int(parameters.echoes / 100 * 6)
        let lineWidth = 0.5 + parameters.stroke / 100 * 4
        let phaseSpread = parameters.variation / 100 * 4
        let clump = parameters.clump / 100

        for index in 0..<strands {
            let n = strands == 1 ? 0.5 : Double(index) / Double(strands - 1)
            // Clump pulls every strand toward the middle without reordering
            // them, so the field tightens rather than scrambling.
            let clumped = 0.5 + (n - 0.5) * (1 - clump * 0.85)
            let baseY = size.height * (0.12 + 0.76 * clumped)
            let phase = Double(index) * phaseSpread

            for echo in stride(from: echoCount, through: 0, by: -1) {
                let lag = Double(echo) * 0.14
                let fade = 1 - Double(echo) / Double(echoCount + 1)

                var path = Path()
                for segment in 0...segments {
                    let t = Double(segment) / Double(segments)
                    let x = t * size.width

                    let envelope = pow(sin(t * .pi), envelopeExponent)
                    let wave = sin(t * frequency * 2 * .pi + phase + (time - lag) * speed)
                    let wobble = sin(
                        t * frequency * 5.3 * .pi + (time - lag) * speed * 1.7 + Double(index)
                    ) * noiseAmount

                    var y = baseY + (wave * amplitude + wobble) * envelope
                    if parameters.mirrored, index % 2 == 1 {
                        y = size.height - y
                    }

                    let point = CGPoint(x: x, y: y)
                    if segment == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }

                context.stroke(
                    path,
                    with: .color(color.opacity(fade * 0.85)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            }
        }
    }
}

#Preview("Canvas") {
    GlitchCanvas(parameters: CanvasParameters(), color: GlitchPalette.signatureAccent)
        .frame(width: 500, height: 320)
        .background(GlitchPalette.dark.background)
}
