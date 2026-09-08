import SwiftUI

// Every icon in the app is drawn here. Nothing in this file uses a system symbol set, an
// emoji or a bundled image — each glyph is a `Shape` laid out in the rectangle it is given.

// MARK: - Marks

/// Four pieces locked into a square — the Puzzles tab.
struct JGQuadMark: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) * 0.86
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let half = side / 2
        let bump = side * 0.11
        var path = Path()

        // outer square
        path.addRoundedRect(in: CGRect(x: origin.x, y: origin.y, width: side, height: side),
                            cornerSize: CGSize(width: side * 0.12, height: side * 0.12))
        // vertical seam with a knob at its middle
        path.move(to: CGPoint(x: origin.x + half, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + half, y: origin.y + half - bump))
        path.addCurve(to: CGPoint(x: origin.x + half, y: origin.y + half + bump),
                      control1: CGPoint(x: origin.x + half + bump * 2, y: origin.y + half - bump),
                      control2: CGPoint(x: origin.x + half + bump * 2, y: origin.y + half + bump))
        path.addLine(to: CGPoint(x: origin.x + half, y: origin.y + side))
        // horizontal seam
        path.move(to: CGPoint(x: origin.x, y: origin.y + half))
        path.addLine(to: CGPoint(x: origin.x + half - bump * 2.4, y: origin.y + half))
        path.move(to: CGPoint(x: origin.x + half + bump * 0.4, y: origin.y + half))
        path.addLine(to: CGPoint(x: origin.x + side, y: origin.y + half))
        return path
    }
}

/// A hung picture frame — the Gallery tab.
struct JGFrameMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let box = CGRect(x: rect.midX - w * 0.44, y: rect.midY - w * 0.40,
                         width: w * 0.88, height: w * 0.80)
        var path = Path()
        path.addRoundedRect(in: box, cornerSize: CGSize(width: w * 0.07, height: w * 0.07))
        let inner = box.insetBy(dx: w * 0.11, dy: w * 0.11)
        path.addRect(inner)
        // a small hill and sun inside the mount
        path.move(to: CGPoint(x: inner.minX, y: inner.maxY))
        path.addLine(to: CGPoint(x: inner.minX + inner.width * 0.36, y: inner.midY))
        path.addLine(to: CGPoint(x: inner.minX + inner.width * 0.66, y: inner.maxY))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: inner.maxX - inner.width * 0.30,
                                   y: inner.minY + inner.height * 0.12,
                                   width: inner.width * 0.20, height: inner.width * 0.20))
        return path
    }
}

/// Three rising columns — the Stats tab. Drawn as bars, never a chart framework.
struct JGColumnsMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let base = rect.midY + w * 0.40
        let barWidth = w * 0.20
        let gap = w * 0.10
        let heights: [CGFloat] = [0.34, 0.58, 0.80]
        var path = Path()
        for (i, h) in heights.enumerated() {
            let x = rect.midX - (barWidth * 1.5 + gap) + CGFloat(i) * (barWidth + gap)
            let height = w * h
            path.addRoundedRect(in: CGRect(x: x, y: base - height, width: barWidth, height: height),
                                cornerSize: CGSize(width: barWidth * 0.3, height: barWidth * 0.3))
        }
        return path
    }
}

/// Three sliders — the Settings tab, drawn rather than borrowed.
struct JGSlidersMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let left = rect.midX - w * 0.40
        let right = rect.midX + w * 0.40
        let rows: [CGFloat] = [-0.28, 0, 0.28]
        let knobAt: [CGFloat] = [0.68, 0.34, 0.56]
        var path = Path()
        for (i, dy) in rows.enumerated() {
            let y = rect.midY + w * dy
            path.move(to: CGPoint(x: left, y: y))
            path.addLine(to: CGPoint(x: right, y: y))
            let cx = left + (right - left) * knobAt[i]
            path.addEllipse(in: CGRect(x: cx - w * 0.09, y: y - w * 0.09,
                                       width: w * 0.18, height: w * 0.18))
        }
        return path
    }
}

// MARK: - Controls

struct JGChevron: Shape {
    /// 0 = right, 1 = left, 2 = up, 3 = down
    var facing: Int = 0
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let a = w * 0.26
        var path = Path()
        switch facing {
        case 1:
            path.move(to: CGPoint(x: rect.midX + a * 0.6, y: rect.midY - a))
            path.addLine(to: CGPoint(x: rect.midX - a * 0.6, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX + a * 0.6, y: rect.midY + a))
        case 2:
            path.move(to: CGPoint(x: rect.midX - a, y: rect.midY + a * 0.6))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - a * 0.6))
            path.addLine(to: CGPoint(x: rect.midX + a, y: rect.midY + a * 0.6))
        case 3:
            path.move(to: CGPoint(x: rect.midX - a, y: rect.midY - a * 0.6))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + a * 0.6))
            path.addLine(to: CGPoint(x: rect.midX + a, y: rect.midY - a * 0.6))
        default:
            path.move(to: CGPoint(x: rect.midX - a * 0.6, y: rect.midY - a))
            path.addLine(to: CGPoint(x: rect.midX + a * 0.6, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX - a * 0.6, y: rect.midY + a))
        }
        return path
    }
}

struct JGCrossMark: Shape {
    func path(in rect: CGRect) -> Path {
        let a = min(rect.width, rect.height) * 0.28
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - a, y: rect.midY - a))
        path.addLine(to: CGPoint(x: rect.midX + a, y: rect.midY + a))
        path.move(to: CGPoint(x: rect.midX + a, y: rect.midY - a))
        path.addLine(to: CGPoint(x: rect.midX - a, y: rect.midY + a))
        return path
    }
}

struct JGTickMark: Shape {
    func path(in rect: CGRect) -> Path {
        let a = min(rect.width, rect.height) * 0.30
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - a, y: rect.midY + a * 0.05))
        path.addLine(to: CGPoint(x: rect.midX - a * 0.25, y: rect.midY + a * 0.68))
        path.addLine(to: CGPoint(x: rect.midX + a, y: rect.midY - a * 0.62))
        return path
    }
}

struct JGPauseMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let bar = w * 0.16
        let height = w * 0.62
        var path = Path()
        path.addRoundedRect(in: CGRect(x: rect.midX - bar * 1.7, y: rect.midY - height / 2,
                                       width: bar, height: height),
                            cornerSize: CGSize(width: bar * 0.4, height: bar * 0.4))
        path.addRoundedRect(in: CGRect(x: rect.midX + bar * 0.7, y: rect.midY - height / 2,
                                       width: bar, height: height),
                            cornerSize: CGSize(width: bar * 0.4, height: bar * 0.4))
        return path
    }
}

/// A turning arrow — the rotation control. The head is placed on the arc's own tangent so it
/// points the way the arrow travels instead of being nailed on at a guessed angle.
struct JGTurnMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let radius = w * 0.30
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let finish = 300.0 * Double.pi / 180

        var path = Path()
        path.addArc(center: centre, radius: radius,
                    startAngle: .degrees(35), endAngle: .degrees(300), clockwise: false)

        let tip = CGPoint(x: centre.x + CGFloat(cos(finish)) * radius,
                          y: centre.y + CGFloat(sin(finish)) * radius)
        let along = CGPoint(x: CGFloat(-sin(finish)), y: CGFloat(cos(finish)))   // tangent
        let outward = CGPoint(x: CGFloat(cos(finish)), y: CGFloat(sin(finish)))  // radial
        let head = w * 0.13

        // An open V rather than a filled triangle: these glyphs are always stroked.
        path.move(to: CGPoint(x: tip.x - along.x * head + outward.x * head * 0.75,
                              y: tip.y - along.y * head + outward.y * head * 0.75))
        path.addLine(to: CGPoint(x: tip.x + along.x * head * 0.35,
                                 y: tip.y + along.y * head * 0.35))
        path.addLine(to: CGPoint(x: tip.x - along.x * head - outward.x * head * 0.75,
                                 y: tip.y - along.y * head - outward.y * head * 0.75))
        return path
    }
}

/// Stacked plates — the reference-image toggle.
struct JGLayersMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        var path = Path()
        for (i, dy) in [CGFloat(-0.24), 0, 0.24].enumerated() {
            // A FRACTION of the glyph, not a length. Mixing the two here made every plate
            // wider than the icon and drew rules clean across its neighbours.
            let inset = CGFloat(i) * 0.05
            let halfWidth = w * (0.36 - inset)
            let box = CGRect(x: rect.midX - halfWidth,
                             y: rect.midY + w * dy - w * 0.075,
                             width: halfWidth * 2,
                             height: w * 0.15)
            path.addRoundedRect(in: box, cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
        }
        return path
    }
}

/// A small burst — the hint control.
struct JGSparkMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        var path = Path()
        let spokes = 8
        for i in 0..<spokes {
            let angle = Double(i) * (2 * Double.pi / Double(spokes))
            let inner = w * (i % 2 == 0 ? 0.12 : 0.10)
            let outer = w * (i % 2 == 0 ? 0.38 : 0.24)
            path.move(to: CGPoint(x: rect.midX + CGFloat(cos(angle)) * inner,
                                  y: rect.midY + CGFloat(sin(angle)) * inner))
            path.addLine(to: CGPoint(x: rect.midX + CGFloat(cos(angle)) * outer,
                                     y: rect.midY + CGFloat(sin(angle)) * outer))
        }
        path.addEllipse(in: CGRect(x: rect.midX - w * 0.08, y: rect.midY - w * 0.08,
                                   width: w * 0.16, height: w * 0.16))
        return path
    }
}

/// Two arrows crossing — the shuffle control.
struct JGShuffleMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let a = w * 0.30
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - a, y: rect.midY - a * 0.7))
        path.addCurve(to: CGPoint(x: rect.midX + a, y: rect.midY + a * 0.7),
                      control1: CGPoint(x: rect.midX, y: rect.midY - a * 0.7),
                      control2: CGPoint(x: rect.midX, y: rect.midY + a * 0.7))
        path.move(to: CGPoint(x: rect.midX - a, y: rect.midY + a * 0.7))
        path.addCurve(to: CGPoint(x: rect.midX + a, y: rect.midY - a * 0.7),
                      control1: CGPoint(x: rect.midX, y: rect.midY + a * 0.7),
                      control2: CGPoint(x: rect.midX, y: rect.midY - a * 0.7))
        for dy in [CGFloat(-0.7), 0.7] {
            let tip = CGPoint(x: rect.midX + a, y: rect.midY + a * dy)
            path.move(to: CGPoint(x: tip.x - a * 0.42, y: tip.y - a * 0.24))
            path.addLine(to: tip)
            path.addLine(to: CGPoint(x: tip.x - a * 0.30, y: tip.y + a * 0.36))
        }
        return path
    }
}

/// A closed padlock — locked gallery cards.
struct JGLockMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let body = CGRect(x: rect.midX - w * 0.26, y: rect.midY - w * 0.04,
                          width: w * 0.52, height: w * 0.40)
        var path = Path()
        path.addRoundedRect(in: body, cornerSize: CGSize(width: w * 0.08, height: w * 0.08))
        path.move(to: CGPoint(x: rect.midX - w * 0.16, y: body.minY))
        path.addLine(to: CGPoint(x: rect.midX - w * 0.16, y: rect.midY - w * 0.18))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY - w * 0.18), radius: w * 0.16,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.midX + w * 0.16, y: body.minY))
        return path
    }
}

/// A day square with a marked corner — the daily puzzle.
struct JGDayMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        let box = CGRect(x: rect.midX - w * 0.34, y: rect.midY - w * 0.30,
                         width: w * 0.68, height: w * 0.64)
        var path = Path()
        path.addRoundedRect(in: box, cornerSize: CGSize(width: w * 0.09, height: w * 0.09))
        path.move(to: CGPoint(x: box.minX, y: box.minY + w * 0.18))
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY + w * 0.18))
        path.move(to: CGPoint(x: box.minX + w * 0.17, y: box.minY - w * 0.08))
        path.addLine(to: CGPoint(x: box.minX + w * 0.17, y: box.minY + w * 0.07))
        path.move(to: CGPoint(x: box.maxX - w * 0.17, y: box.minY - w * 0.08))
        path.addLine(to: CGPoint(x: box.maxX - w * 0.17, y: box.minY + w * 0.07))
        path.addEllipse(in: CGRect(x: rect.midX - w * 0.09, y: box.maxY - w * 0.28,
                                   width: w * 0.18, height: w * 0.18))
        return path
    }
}

/// A rising flame — the daily streak.
struct JGStreakMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY - w * 0.38))
        path.addCurve(to: CGPoint(x: rect.midX + w * 0.26, y: rect.midY + w * 0.14),
                      control1: CGPoint(x: rect.midX + w * 0.16, y: rect.midY - w * 0.16),
                      control2: CGPoint(x: rect.midX + w * 0.26, y: rect.midY - w * 0.06))
        path.addCurve(to: CGPoint(x: rect.midX - w * 0.26, y: rect.midY + w * 0.14),
                      control1: CGPoint(x: rect.midX + w * 0.24, y: rect.midY + w * 0.44),
                      control2: CGPoint(x: rect.midX - w * 0.24, y: rect.midY + w * 0.44))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.midY - w * 0.38),
                      control1: CGPoint(x: rect.midX - w * 0.28, y: rect.midY - w * 0.08),
                      control2: CGPoint(x: rect.midX - w * 0.06, y: rect.midY - w * 0.10))
        path.closeSubpath()
        return path
    }
}

/// A ring with a hand — the timer readout.
struct JGDialMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = min(rect.width, rect.height)
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.midX - w * 0.34, y: rect.midY - w * 0.34,
                                   width: w * 0.68, height: w * 0.68))
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY - w * 0.20))
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX + w * 0.15, y: rect.midY + w * 0.06))
        return path
    }
}

// MARK: - Reusable icon buttons

/// A round control whose label is a stroked glyph. The tap target is set explicitly,
/// because a shape drawn over nothing has none of its own.
struct JGRoundButton<G: Shape>: View {
    let glyph: G
    var diameter: CGFloat = 44
    var lineWidth: CGFloat = 2
    var tint: Color = JGPalette.ink
    var fill: Color = JGPalette.card
    var border: Color = JGPalette.cardEdge
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            ZStack {
                Circle().fill(fill)
                Circle().stroke(border, lineWidth: 1)
                glyph
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .foregroundColor(tint)
                    .frame(width: diameter * 0.56, height: diameter * 0.56)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.38)
        }
        .buttonStyle(JGPressStyle())
    }
}

/// A flat pill control with a glyph and a caption.
struct JGPillButton<G: Shape>: View {
    let glyph: G
    let title: String
    var active: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 7) {
                glyph
                    .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(active ? Color.white : JGPalette.ink)
                    .frame(width: 17, height: 17)
                Text(title)
                    .font(JGFont.title(13))
                    .foregroundColor(active ? Color.white : JGPalette.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? JGPalette.teal : JGPalette.card)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(active ? JGPalette.teal : JGPalette.cardEdge, lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
            .opacity(enabled ? 1 : 0.38)
        }
        .buttonStyle(JGPressStyle())
    }
}

/// A wide primary action.
struct JGWideButton: View {
    let title: String
    var subtitle: String? = nil
    var tone: Color = JGPalette.teal
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(JGFont.title(16))
                    .foregroundColor(.white)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(JGFont.body(12))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tone)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(JGPressStyle())
    }
}

struct JGPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A two-state switch drawn from scratch — no system toggle chrome anywhere.
struct JGSwitch: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? JGPalette.teal : JGPalette.cardEdge)
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 3)
                    .shadow(color: Color.black.opacity(0.12), radius: 1.5, x: 0, y: 1)
            }
            .frame(width: 50, height: 30)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.16), value: isOn)
        }
        .buttonStyle(JGPressStyle())
    }
}

/// A segmented chooser built from plain buttons.
struct JGSegments: View {
    let options: [String]
    let selection: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: { onSelect(index) }) {
                    Text(options[index])
                        .font(JGFont.title(13))
                        .foregroundColor(index == selection ? .white : JGPalette.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(index == selection ? JGPalette.teal : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(JGPressStyle())
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(JGPalette.tray)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(JGPalette.trayEdge, lineWidth: 1)
        )
    }
}

/// A horizontal progress rail — used for collection progress and tier completion.
struct JGProgressRail: View {
    let value: Double          // 0...1
    var tone: Color = JGPalette.teal
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(JGPalette.cardEdge.opacity(0.55))
                Capsule()
                    .fill(tone)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
