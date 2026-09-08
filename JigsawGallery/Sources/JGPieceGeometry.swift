import CoreGraphics
import SwiftUI

// MARK: - Deterministic randomness

/// SplitMix64. Seeded from the puzzle's own seed, so the same picture at the same tier is
/// cut exactly the same way on every launch and on every device.
struct JGRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func nextBits() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> CGFloat {
        CGFloat(Double(nextBits() >> 11) * (1.0 / 9_007_199_254_740_992.0))
    }

    mutating func between(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        low + (high - low) * unit()
    }

    mutating func index(below limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        return Int(nextBits() % UInt64(limit))
    }
}

/// A stable 64-bit hash for strings — used to turn a picture id or a calendar date into a
/// seed without depending on Swift's per-process `hashValue`.
func jgStableSeed(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01B3
    }
    return hash
}

// MARK: - One seam between two pieces

/// A seam runs in a canonical direction — left to right for a horizontal cut, top to bottom
/// for a vertical one — and both pieces that share it read the SAME record. That is what
/// makes a knob and its socket line up: neither piece invents its own edge.
struct JGSeam {
    /// +1 = the seam bulges along its canonical normal (down for a horizontal cut, right for
    /// a vertical one); -1 = it bulges the other way.
    let bulge: CGFloat
    /// Slide of the knob along the seam, so the cut does not look machine-stamped.
    let slide: CGFloat
    /// Height of the knob as a fraction of the seam's length.
    let depth: CGFloat
}

/// One normalized cubic of a seam profile. `u` runs 0 → 1 along the seam, `v` away from it.
private struct JGProfileSegment {
    let c1: CGPoint
    let c2: CGPoint
    let end: CGPoint
}

private struct JGSeamProfile {
    let start: CGPoint
    let segments: [JGProfileSegment]

    /// The classic knob: a flat run, a pinched neck, a round head, the mirrored neck, and a
    /// second flat run. Peak height is normalised to exactly `seam.depth`.
    init(seam: JGSeam) {
        let j = seam.slide
        let k = seam.depth / 0.32          // the raw table peaks at 0.32
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: u + j, y: v * k) }

        let neckStart = CGPoint(x: 0.36 + j, y: 0)
        let neckEnd = CGPoint(x: 0.64 + j, y: 0)

        start = CGPoint(x: 0, y: 0)
        segments = [
            // leading flat run, written as a cubic so every segment is the same shape
            JGProfileSegment(c1: CGPoint(x: neckStart.x / 3, y: 0),
                             c2: CGPoint(x: neckStart.x * 2 / 3, y: 0),
                             end: neckStart),
            // out of the flat, pinching inward before the head flares
            JGProfileSegment(c1: p(0.46, 0.02), c2: p(0.32, 0.14), end: p(0.42, 0.20)),
            // the round head
            JGProfileSegment(c1: p(0.36, 0.36), c2: p(0.64, 0.36), end: p(0.58, 0.20)),
            // mirror of the neck
            JGProfileSegment(c1: p(0.68, 0.14), c2: p(0.54, 0.02), end: neckEnd),
            // trailing flat run
            JGProfileSegment(c1: CGPoint(x: neckEnd.x + (1 - neckEnd.x) / 3, y: 0),
                             c2: CGPoint(x: neckEnd.x + (1 - neckEnd.x) * 2 / 3, y: 0),
                             end: CGPoint(x: 1, y: 0))
        ]
    }
}

// MARK: - The cut

/// Every seam of one puzzle, decided once from the puzzle's seed.
struct JGCutPattern {
    let columns: Int
    let rows: Int
    /// Seam below piece (column, row) — `rows - 1` rows of them.
    let horizontal: [[JGSeam]]
    /// Seam to the right of piece (column, row) — `columns - 1` per row.
    let vertical: [[JGSeam]]

    var pieceCount: Int { columns * rows }

    init(columns: Int, rows: Int, seed: UInt64) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        var rng = JGRandom(seed: seed)

        func makeSeam() -> JGSeam {
            JGSeam(bulge: rng.unit() < 0.5 ? -1 : 1,
                   slide: rng.between(-0.05, 0.05),
                   depth: rng.between(0.21, 0.29))
        }

        var horiz: [[JGSeam]] = []
        if self.rows > 1 {
            for _ in 0..<(self.rows - 1) {
                horiz.append((0..<self.columns).map { _ in makeSeam() })
            }
        }
        var vert: [[JGSeam]] = []
        for _ in 0..<self.rows {
            if self.columns > 1 {
                vert.append((0..<(self.columns - 1)).map { _ in makeSeam() })
            } else {
                vert.append([])
            }
        }
        horizontal = horiz
        vertical = vert
    }

    func index(column: Int, row: Int) -> Int { row * columns + column }
    func column(of index: Int) -> Int { index % columns }
    func row(of index: Int) -> Int { index / columns }

    /// Seam above / below / left of / right of a piece, or nil at the board edge.
    func seamAbove(column: Int, row: Int) -> JGSeam? {
        guard row > 0, row - 1 < horizontal.count, column < columns else { return nil }
        return horizontal[row - 1][column]
    }
    func seamBelow(column: Int, row: Int) -> JGSeam? {
        guard row < horizontal.count, column < columns else { return nil }
        return horizontal[row][column]
    }
    func seamLeft(column: Int, row: Int) -> JGSeam? {
        guard column > 0, row < vertical.count, column - 1 < vertical[row].count else { return nil }
        return vertical[row][column - 1]
    }
    func seamRight(column: Int, row: Int) -> JGSeam? {
        guard row < vertical.count, column < vertical[row].count else { return nil }
        return vertical[row][column]
    }

    func isEdgePiece(_ index: Int) -> Bool {
        let c = column(of: index), r = row(of: index)
        return c == 0 || r == 0 || c == columns - 1 || r == rows - 1
    }

    func isCornerPiece(_ index: Int) -> Bool {
        let c = column(of: index), r = row(of: index)
        return (c == 0 || c == columns - 1) && (r == 0 || r == rows - 1)
    }
}

// MARK: - Outlines

/// Builds and caches every piece outline. Paths are cut once per puzzle in a unit cell and
/// then re-scaled only when the board or the tray actually changes size — never per frame.
final class JGPuzzleGeometry {

    let cut: JGCutPattern
    /// Width and height of one cell in unit space, where the whole board is always
    /// `jgBoardUnits` across. Equal at three of the five cuts and near enough at the other two.
    let cellWidth: CGFloat
    let cellHeight: CGFloat

    /// Outline of each piece with its own cell at the origin. Knobs run outside that box, so
    /// the bounding boxes below are larger than one cell.
    private(set) var unitPaths: [Path] = []
    /// Bounding box of each of those outlines, in unit space.
    private(set) var unitBoxes: [CGRect] = []
    /// The same outlines placed at their home cell. The board layer draws in this space and
    /// lets the canvas transform carry the zoom, so nothing here is ever rebuilt — not on a
    /// resize, not on a pinch.
    private(set) var unitBoardPaths: [Path] = []

    /// Loose outlines, cached per scale. There are two live scales during a drag — the tray
    /// thumbnail and the piece under the finger, drawn at board size — so a single slot would
    /// be evicted twice a frame and rebuild every outline both times.
    private var looseCache: [Int: [Path]] = [:]
    private var looseOrder: [Int] = []

    init(cut: JGCutPattern) {
        self.cut = cut
        cellWidth = jgBoardUnits.width / CGFloat(max(1, cut.columns))
        cellHeight = jgBoardUnits.height / CGFloat(max(1, cut.rows))
        buildUnitPaths()
    }

    private func buildUnitPaths() {
        var paths: [Path] = []
        var boxes: [CGRect] = []
        var board: [Path] = []
        paths.reserveCapacity(cut.pieceCount)
        boxes.reserveCapacity(cut.pieceCount)
        board.reserveCapacity(cut.pieceCount)
        for index in 0..<cut.pieceCount {
            let local = outline(for: index, scale: 1, origin: .zero)
            paths.append(local)
            boxes.append(local.boundingRect)
            board.append(outline(for: index, scale: 1, origin: cellOrigin(index)))
        }
        unitPaths = paths
        unitBoxes = boxes
        unitBoardPaths = board
    }

    /// Top-left corner of a piece's home cell, in unit space.
    func cellOrigin(_ index: Int) -> CGPoint {
        CGPoint(x: CGFloat(cut.column(of: index)) * cellWidth,
                y: CGFloat(cut.row(of: index)) * cellHeight)
    }

    /// Outline of one piece with its cell's corner at `origin`. `scale` is how many points
    /// one unit is worth — 1 while the outline is being kept in unit space.
    func outline(for index: Int, scale: CGFloat, origin: CGPoint) -> Path {
        let c = cut.column(of: index)
        let r = cut.row(of: index)
        let width = cellWidth * scale
        let height = cellHeight * scale
        let topLeft = origin
        let topRight = CGPoint(x: origin.x + width, y: origin.y)
        let bottomRight = CGPoint(x: origin.x + width, y: origin.y + height)
        let bottomLeft = CGPoint(x: origin.x, y: origin.y + height)

        var path = Path()
        path.move(to: topLeft)

        // Top: canonical left → right, normal pointing down. Walked forward.
        appendEdge(&path, seam: cut.seamAbove(column: c, row: r),
                   from: topLeft, to: topRight, normal: CGPoint(x: 0, y: 1),
                   length: width, reversed: false, fallback: topRight)

        // Right: canonical top → bottom, normal pointing right. Walked forward.
        appendEdge(&path, seam: cut.seamRight(column: c, row: r),
                   from: topRight, to: bottomRight, normal: CGPoint(x: 1, y: 0),
                   length: height, reversed: false, fallback: bottomRight)

        // Bottom: the canonical seam runs left → right, but the outline walks right → left.
        appendEdge(&path, seam: cut.seamBelow(column: c, row: r),
                   from: bottomLeft, to: bottomRight, normal: CGPoint(x: 0, y: 1),
                   length: width, reversed: true, fallback: bottomLeft)

        // Left: canonical top → bottom, walked bottom → top.
        appendEdge(&path, seam: cut.seamLeft(column: c, row: r),
                   from: topLeft, to: bottomLeft, normal: CGPoint(x: 1, y: 0),
                   length: height, reversed: true, fallback: topLeft)

        path.closeSubpath()
        return path
    }

    /// `from`/`to` are the seam's canonical endpoints. `reversed` means the outline is
    /// walking it backwards, in which case the very same curve is emitted end-first — which
    /// is why a knob and its socket cannot drift apart.
    private func appendEdge(_ path: inout Path,
                            seam: JGSeam?,
                            from: CGPoint,
                            to: CGPoint,
                            normal: CGPoint,
                            length: CGFloat,
                            reversed: Bool,
                            fallback: CGPoint) {
        guard let seam = seam, length > 0 else {
            path.addLine(to: fallback)
            return
        }
        let direction = CGPoint(x: (to.x - from.x) / length, y: (to.y - from.y) / length)
        let bulge = seam.bulge
        func place(_ p: CGPoint) -> CGPoint {
            CGPoint(x: from.x + direction.x * p.x * length + normal.x * p.y * length * bulge,
                    y: from.y + direction.y * p.x * length + normal.y * p.y * length * bulge)
        }

        let profile = JGSeamProfile(seam: seam)
        if reversed {
            var tail = profile.segments.count - 1
            while tail >= 0 {
                let segment = profile.segments[tail]
                let previousEnd = tail == 0 ? profile.start : profile.segments[tail - 1].end
                path.addCurve(to: place(previousEnd),
                              control1: place(segment.c2),
                              control2: place(segment.c1))
                tail -= 1
            }
        } else {
            for segment in profile.segments {
                path.addCurve(to: place(segment.end),
                              control1: place(segment.c1),
                              control2: place(segment.c2))
            }
        }
    }

    // MARK: Loose pieces

    /// Outlines for a piece drawn on its own — a tray thumbnail, or the one under the finger.
    /// Already shifted so the outline's bounding box starts at (0, 0), which is what a
    /// SwiftUI view's local coordinate space expects. Cached per scale.
    /// The scale a loose outline is actually built at. Callers must size their frames with
    /// this and not the raw value, or the clip shape and the frame drift apart.
    func snappedScale(_ scale: CGFloat) -> CGFloat {
        CGFloat(Int((max(0.1, scale) * 10).rounded())) / 10
    }

    func loosePaths(scale: CGFloat) -> [Path] {
        // Quantised to a tenth of a point: a pinch produces a continuum of scales and every
        // distinct one would otherwise be its own cache entry.
        let slot = Int((max(0.1, scale) * 10).rounded())
        if let cached = looseCache[slot] { return cached }
        let quantised = CGFloat(slot) / 10
        let built = (0..<cut.pieceCount).map { index -> Path in
            let box = looseBox(index, scale: quantised)
            return outline(for: index, scale: quantised,
                           origin: CGPoint(x: -box.minX, y: -box.minY))
        }
        looseCache[slot] = built
        looseOrder.append(slot)
        while looseOrder.count > 4 {
            let dropped = looseOrder.removeFirst()
            looseCache.removeValue(forKey: dropped)
        }
        return built
    }

    /// Bounding box of a loose piece at the given scale, relative to its cell's corner.
    func looseBox(_ index: Int, scale: CGFloat) -> CGRect {
        guard index >= 0, index < unitBoxes.count else {
            return CGRect(x: 0, y: 0, width: cellWidth * scale, height: cellHeight * scale)
        }
        let box = unitBoxes[index]
        return CGRect(x: box.minX * scale, y: box.minY * scale,
                      width: box.width * scale, height: box.height * scale)
    }

    /// The scale at which a piece's cell comes out roughly `target` points across — used to
    /// keep tray pieces a consistent size whether there are six of them or ninety-six.
    func scaleForCell(_ target: CGFloat) -> CGFloat {
        target / max(0.0001, max(cellWidth, cellHeight))
    }

    /// Where the centre of a piece's home cell sits in unit space.
    func unitHomeCentre(_ index: Int) -> CGPoint {
        CGPoint(x: (CGFloat(cut.column(of: index)) + 0.5) * cellWidth,
                y: (CGFloat(cut.row(of: index)) + 0.5) * cellHeight)
    }

    /// Snap distance in unit space, taken from the smaller side of a cell so a piece can
    /// never be dropped closer to a neighbour's home than to its own.
    func snapRadius(fraction: CGFloat) -> CGFloat {
        min(cellWidth, cellHeight) * fraction
    }
}

// MARK: - Shape wrapper

/// Lets a prepared `Path` be used anywhere a `Shape` is wanted (`clipShape`, `stroke`).
struct JGPathShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path }
}

/// The rectangle a square source image fills when it is centre-cropped onto `board`. The
/// board is the same shape at every cut, so this is the same crop everywhere in the app —
/// the shelf card, the gallery frame and the board itself all show the identical picture.
func jgFillRect(board: CGSize = jgBoardUnits) -> CGRect {
    let side = max(board.width, board.height)
    return CGRect(x: (board.width - side) / 2,
                  y: (board.height - side) / 2,
                  width: side, height: side)
}
