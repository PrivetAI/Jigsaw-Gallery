import SwiftUI

private struct JGTrayWindowKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private enum JGStripMode { case pan, lift }

/// The loose pieces, laid out in lanes along one axis and panned by hand.
///
/// It deliberately does not use a `ScrollView`: a scroll view delays touches and cancels them
/// on drift, which is exactly the input a piece has to survive to be dragged out of here.
/// Owning the gesture means a sideways drag pans the strip and any other drag lifts a piece,
/// decided on the first few points of movement.
struct JGTrayStrip: View {

    @ObservedObject var session: JGSession
    /// Roughly how many points a piece's cell should measure in the strip.
    let cell: CGFloat
    let lanes: Int
    let vertical: Bool
    let carried: Int?
    let onLiftChanged: (Int, DragGesture.Value) -> Void
    let onLiftEnded: (Int, DragGesture.Value) -> Void
    let onTap: (Int) -> Void

    @State private var scroll: CGFloat = 0
    @State private var anchor: CGFloat = 0
    @State private var mode: JGStripMode? = nil
    @State private var window: CGFloat = 0

    private var pieces: [Int] { session.trayPieces }
    /// Points per unit that makes a cell about `cell` points across, whatever the cut. Taken
    /// through the same rounding the outline cache uses, so the frame and the clip agree.
    private var pieceScale: CGFloat {
        session.geometry.snappedScale(session.geometry.scaleForCell(cell))
    }
    private var step: CGFloat { cell * 1.46 }
    private var slotCount: Int {
        guard lanes > 0 else { return 0 }
        return (pieces.count + lanes - 1) / lanes
    }
    private var contentExtent: CGFloat { CGFloat(slotCount) * step }
    private var lowestScroll: CGFloat { min(0, window - contentExtent) }

    private func clamp(_ value: CGFloat) -> CGFloat {
        max(lowestScroll, min(0, value))
    }

    var body: some View {
        GeometryReader { geo in
            let extent = vertical ? geo.size.height : geo.size.width
            let across = vertical ? geo.size.width : geo.size.height
            let offset = clamp(scroll)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .preference(key: JGTrayWindowKey.self, value: extent)

                if pieces.isEmpty {
                    emptyNote
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ForEach(visiblePositions(extent: extent, offset: offset), id: \.self) { position in
                        pieceCell(pieces[position],
                                  slot: position / max(1, lanes),
                                  lane: position % max(1, lanes),
                                  offset: offset,
                                  across: across)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
        }
        .onPreferenceChange(JGTrayWindowKey.self) { window = $0 }
        .onChange(of: session.trayFilter) { _ in scroll = 0 }
        .onChange(of: session.shuffleStamp) { _ in scroll = 0 }
    }

    /// Only the pieces that can actually be on screen are built. Ninety-six live views in a
    /// strip that shows eight of them is the difference between smooth and unusable.
    private func visiblePositions(extent: CGFloat, offset: CGFloat) -> [Int] {
        guard slotCount > 0, step > 0, lanes > 0 else { return [] }
        let firstSlot = max(0, Int(((-offset) / step).rounded(.down)) - 1)
        let lastSlot = min(slotCount - 1, Int(((-offset + extent) / step).rounded(.up)) + 1)
        guard firstSlot <= lastSlot else { return [] }
        let lower = firstSlot * lanes
        let upper = min(pieces.count - 1, (lastSlot + 1) * lanes - 1)
        guard lower <= upper else { return [] }
        return Array(lower...upper)
    }

    private func pieceCell(_ index: Int, slot: Int, lane: Int,
                           offset: CGFloat, across: CGFloat) -> some View {
        let box = session.geometry.looseBox(index, scale: pieceScale)
        let laneRoom = lanes > 0 ? across / CGFloat(lanes) : across
        let alongPosition = CGFloat(slot) * step + offset
        let acrossPosition = CGFloat(lane) * laneRoom
        let alongInset = (step - (vertical ? box.height : box.width)) / 2
        let acrossInset = (laneRoom - (vertical ? box.width : box.height)) / 2
        let x = vertical ? acrossPosition + acrossInset : alongPosition + alongInset
        let y = vertical ? alongPosition + alongInset : acrossPosition + acrossInset

        return JGLoosePiece(asset: session.picture.asset,
                            index: index,
                            geometry: session.geometry,
                            scale: pieceScale,
                            quarterTurns: session.rotations.indices.contains(index)
                                ? session.rotations[index] : 0,
                            highlighted: session.selected == index)
            .opacity(carried == index ? 0.22 : 1)
            // The tap target is stated on the piece's own box, before it is moved into
            // place, so it can never grow into a strip-wide swallowing rectangle.
            .contentShape(Rectangle())
            .onTapGesture { onTap(index) }
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .named(JGSpace.name))
                    .onChanged { value in handleChange(index, value) }
                    .onEnded { value in handleEnd(index, value) }
            )
            .offset(x: x, y: y)
    }

    private func handleChange(_ index: Int, _ value: DragGesture.Value) {
        if mode == nil {
            let dx = abs(value.translation.width)
            let dy = abs(value.translation.height)
            let panning = vertical ? dy > dx * 1.2 : dx > dy * 1.2
            mode = panning ? .pan : .lift
            anchor = clamp(scroll)
        }
        if mode == .pan {
            scroll = clamp(anchor + (vertical ? value.translation.height : value.translation.width))
        } else {
            onLiftChanged(index, value)
        }
    }

    private func handleEnd(_ index: Int, _ value: DragGesture.Value) {
        if mode == .lift {
            onLiftEnded(index, value)
        } else {
            scroll = clamp(scroll)
        }
        mode = nil
    }

    private var emptyNote: some View {
        VStack(spacing: 5) {
            JGQuadMark()
                .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .foregroundColor(JGPalette.inkFaint)
                .frame(width: 24, height: 24)
            Text(emptyMessage)
                .font(JGFont.body(11))
                .foregroundColor(JGPalette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }

    private var emptyMessage: String {
        if session.looseCount == 0 { return "Every piece is home." }
        switch session.trayFilter {
        case 1: return "No edge pieces left. Switch back to All."
        case 2: return "No corner pieces left. Switch back to All."
        default: return "Every piece is home."
        }
    }
}
