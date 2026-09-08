import SwiftUI

/// The whole seated board in a single drawing pass: felt, the reference image, every piece
/// already home, and the seams between them. Individual views are kept for the loose pieces
/// only, because ninety-six of them would not survive being separate views.
///
/// Everything is drawn in *unit space* — one unit per cell — and the canvas transform carries
/// the zoom, so no path is ever rebuilt while the player pinches.
struct JGBoardLayer: View, Equatable {

    let asset: String
    /// The board's size in units — always `jgBoardUnits`, whatever the cut.
    let unitSize: CGSize
    /// Screen points per unit at the current zoom.
    let unitScale: CGFloat
    /// Cell size in units, so the ruled grid can be drawn without knowing the cut.
    let cellSize: CGSize
    /// Where unit (0, 0) sits inside this view.
    let boardOrigin: CGPoint
    /// The viewport this canvas fills. Passed in from the parent — the canvas closure's own
    /// `size` argument is not the parent's size and must not be used for camera maths.
    let viewport: CGSize
    let seatedShape: Path
    let seatedSeams: Path
    /// Bumped by the session every time a piece is seated. Compared instead of the paths
    /// themselves, which would mean serialising ninety-six outlines on every equality check.
    let seatedRevision: Int
    let ghostMode: Int
    /// Centre of the piece that just settled, in unit space, and how far the ripple has run.
    let flashCentre: CGPoint
    let flashAmount: Double

    static func == (lhs: JGBoardLayer, rhs: JGBoardLayer) -> Bool {
        lhs.asset == rhs.asset
            && lhs.unitSize == rhs.unitSize
            && lhs.unitScale == rhs.unitScale
            && lhs.cellSize == rhs.cellSize
            && lhs.boardOrigin == rhs.boardOrigin
            && lhs.viewport == rhs.viewport
            && lhs.ghostMode == rhs.ghostMode
            && lhs.flashCentre == rhs.flashCentre
            && lhs.flashAmount == rhs.flashAmount
            && lhs.seatedRevision == rhs.seatedRevision
    }

    var body: some View {
        Canvas { context, _ in
            guard unitScale > 0, unitSize.width > 0, unitSize.height > 0 else { return }
            context.translateBy(x: boardOrigin.x, y: boardOrigin.y)
            context.scaleBy(x: unitScale, y: unitScale)

            let board = CGRect(origin: .zero, size: unitSize)
            let hairline = 1 / unitScale
            // Resolved once. Doing it per layer costs a second lookup on every frame of a pan.
            let picture = context.resolve(Image(asset))

            // Felt
            context.fill(Path(board), with: .color(JGPalette.felt))

            // The ruled cells, so an empty board still says where pieces go
            var rule = Path()
            if cellSize.width > 0.001 {
                var x = cellSize.width
                while x < unitSize.width - 0.001 {
                    rule.move(to: CGPoint(x: x, y: 0))
                    rule.addLine(to: CGPoint(x: x, y: unitSize.height))
                    x += cellSize.width
                }
            }
            if cellSize.height > 0.001 {
                var y = cellSize.height
                while y < unitSize.height - 0.001 {
                    rule.move(to: CGPoint(x: 0, y: y))
                    rule.addLine(to: CGPoint(x: unitSize.width, y: y))
                    y += cellSize.height
                }
            }
            context.stroke(rule, with: .color(JGPalette.feltRule), lineWidth: hairline)

            // The reference image, at whatever strength the player asked for
            if ghostMode > 0 {
                context.drawLayer { layer in
                    layer.clip(to: Path(board))
                    layer.opacity = ghostMode == 2 ? 0.80 : 0.22
                    layer.draw(picture, in: imageRect)
                }
            }

            // Everything already seated, painted through the union of its outlines
            if !seatedShape.isEmpty {
                context.drawLayer { layer in
                    layer.clip(to: seatedShape)
                    layer.draw(picture, in: imageRect)
                }
                context.stroke(seatedSeams,
                               with: .color(Color.black.opacity(0.28)),
                               lineWidth: hairline * 1.1)
                context.stroke(seatedSeams,
                               with: .color(Color.white.opacity(0.30)),
                               lineWidth: hairline * 0.5)
            }

            // The ripple a piece leaves when it settles
            if flashAmount > 0.001 {
                let reach = min(cellSize.width, cellSize.height)
                let radius = reach * (0.3 + 0.9 * CGFloat(flashAmount))
                let ring = Path(ellipseIn: CGRect(x: flashCentre.x - radius,
                                                  y: flashCentre.y - radius,
                                                  width: radius * 2, height: radius * 2))
                context.stroke(ring,
                               with: .color(Color.white.opacity(0.75 * (1 - flashAmount))),
                               lineWidth: hairline * 2.4)
            }

            // Board edge last, so nothing paints over it
            context.stroke(Path(board), with: .color(JGPalette.feltEdge), lineWidth: hairline * 2)
        }
        .frame(width: viewport.width, height: viewport.height)
        .allowsHitTesting(false)
    }

    /// Where the square source picture lands once it is centre-cropped onto the board.
    private var imageRect: CGRect { jgFillRect(board: unitSize) }
}

/// One loose piece: its slice of the picture, clipped to its own outline. Used in the tray
/// and for the piece under the finger — never for a piece that is already home.
struct JGLoosePiece: View {

    let asset: String
    let index: Int
    let geometry: JGPuzzleGeometry
    /// Points per unit at the size this piece should be drawn.
    let scale: CGFloat
    var quarterTurns: Int = 0
    var highlighted: Bool = false
    var highlightTone: Color = JGPalette.amber
    var shadow: Bool = true

    var body: some View {
        // The outline cache works in tenths of a point, so the frame has to be measured at
        // that same rounded scale or the clip shape and the frame drift apart.
        let drawn = geometry.snappedScale(scale)
        let box = geometry.looseBox(index, scale: drawn)
        let outline = geometry.loosePaths(scale: drawn)
        let path = index < outline.count ? outline[index] : Path()
        let fill = jgFillRect()
        let home = geometry.cellOrigin(index)
        // The picture is positioned so the piece's own cell lines up with where that cell
        // sits on the full board.
        let imageX = (fill.minX - home.x) * drawn - box.minX
        let imageY = (fill.minY - home.y) * drawn - box.minY
        let side = fill.width * drawn

        return Color.clear
            .frame(width: box.width, height: box.height)
            .overlay(
                Image(asset)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: side, height: side)
                    .offset(x: imageX, y: imageY),
                alignment: .topLeading
            )
            .clipShape(JGPathShape(path: path))
            .overlay(
                JGPathShape(path: path)
                    .stroke(highlighted ? highlightTone : Color.black.opacity(0.30),
                            lineWidth: highlighted ? 2.4 : 0.8)
            )
            .shadow(color: Color.black.opacity(shadow ? 0.28 : 0),
                    radius: shadow ? 5 : 0, x: 0, y: shadow ? 3 : 0)
            .rotationEffect(.degrees(Double(quarterTurns) * 90))
    }
}
