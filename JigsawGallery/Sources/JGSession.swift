import CoreGraphics
import Foundation
import SwiftUI

/// How a puzzle screen was opened, so the screen knows what to restore and what to record.
struct JGLaunch: Identifiable, Equatable {
    let picture: JGPicture
    let tier: JGTier
    let seed: UInt64
    let isDaily: Bool
    let dayKey: String
    /// A half-finished board to pick up rather than start over.
    let resume: JGActivePuzzle?

    var id: String { "\(picture.id)#\(tier.id)#\(isDaily ? dayKey : "free")" }

    static func == (lhs: JGLaunch, rhs: JGLaunch) -> Bool { lhs.id == rhs.id }
}

/// The live state of one board. Kept apart from `JGStore` so that dragging a piece around
/// never republishes the whole app.
final class JGSession: ObservableObject {

    let picture: JGPicture
    let tier: JGTier
    let seed: UInt64
    let isDaily: Bool
    let dayKey: String
    let geometry: JGPuzzleGeometry

    @Published private(set) var seated: Set<Int> = []
    @Published private(set) var rotations: [Int]
    @Published private(set) var trayOrder: [Int]
    @Published private(set) var moves: Int = 0
    @Published private(set) var hintsUsed: Int = 0
    @Published private(set) var finished = false
    @Published var rotationMode: Bool
    @Published var ghostMode: Int
    @Published var paused = false
    @Published var selected: Int? = nil
    /// 0 = all · 1 = edges only · 2 = corners only
    @Published var trayFilter: Int = 0
    /// Bumped by `shuffleTray`, so the strip knows to jump back to its start.
    @Published private(set) var shuffleStamp = 0

    /// Union of every seated outline, in unit space (one unit per cell). Rebuilt only when a
    /// piece is actually seated, never per frame.
    @Published private(set) var seatedShape = Path()
    /// The seams between seated pieces, as one strokeable path.
    @Published private(set) var seatedSeams = Path()
    /// Bumped whenever the two paths above are rebuilt, so the board layer can decide
    /// whether it needs redrawing without comparing ninety-six outlines.
    @Published private(set) var seatedRevision = 0
    /// Index and birth date of the most recent seat, for the settling animation.
    @Published private(set) var lastSeated: Int? = nil

    /// Pieces put down since the lifetime count was last credited, so an abandoned board — or
    /// one the system kills while it is in the background — still counts what was done.
    private(set) var placedThisRun = 0

    /// Hands back everything not yet credited and resets the tally, so no piece is ever
    /// counted twice however many times this is called.
    func takePlacedCredit() -> Int {
        let owed = placedThisRun
        placedThisRun = 0
        return owed
    }

    private var accumulated: Double
    private var runningSince: Date?

    var pieceCount: Int { tier.pieceCount }
    var placedCount: Int { seated.count }
    var remainingCount: Int { pieceCount - seated.count }
    var boardUnitSize: CGSize { jgBoardUnits }
    var cellUnitSize: CGSize { CGSize(width: geometry.cellWidth, height: geometry.cellHeight) }

    var elapsed: Double {
        guard let since = runningSince else { return accumulated }
        return accumulated + Date().timeIntervalSince(since)
    }

    var progress: Double {
        pieceCount == 0 ? 0 : Double(seated.count) / Double(pieceCount)
    }

    // MARK: Setting up

    init(launch: JGLaunch, prefs: JGPrefs) {
        picture = launch.picture
        tier = launch.tier
        seed = launch.seed
        isDaily = launch.isDaily
        dayKey = launch.dayKey
        geometry = JGPuzzleGeometry(cut: JGCutPattern(columns: launch.tier.columns,
                                                      rows: launch.tier.rows,
                                                      seed: launch.seed))

        let count = launch.tier.pieceCount
        if let saved = launch.resume, saved.rotations.count == count, saved.trayOrder.count == count {
            rotations = saved.rotations.map { max(0, min(3, $0)) }
            trayOrder = saved.trayOrder
            seated = Set(saved.seated.filter { $0 >= 0 && $0 < count })
            moves = max(0, saved.moves)
            hintsUsed = max(0, saved.hintsUsed)
            rotationMode = saved.rotationMode
            ghostMode = max(0, min(2, saved.ghostMode))
            accumulated = max(0, saved.elapsed)
        } else {
            var rng = JGRandom(seed: launch.seed &+ 0x51_23_AB)
            rotationMode = prefs.rotationDefault
            ghostMode = prefs.ghostDefault
            var order = Array(0..<count)
            // Fisher-Yates, from the puzzle's own generator so a restart of the same puzzle
            // deals the tray the same way.
            var i = count - 1
            while i > 0 {
                let j = rng.index(below: i + 1)
                order.swapAt(i, j)
                i -= 1
            }
            trayOrder = order
            rotations = (0..<count).map { _ in prefs.rotationDefault ? rng.index(below: 4) : 0 }
            accumulated = 0
        }
        // A board restored with every piece down is finished; nothing else can seat one.
        finished = seated.count == count && count > 0
        rebuildSeatedShapes()
    }

    // MARK: The clock

    func resumeClock() {
        guard !finished, !paused, runningSince == nil else { return }
        runningSince = Date()
    }

    func holdClock() {
        guard let since = runningSince else { return }
        accumulated += Date().timeIntervalSince(since)
        runningSince = nil
    }

    func setPaused(_ value: Bool) {
        guard paused != value else { return }
        paused = value
        if value { holdClock() } else { resumeClock() }
    }

    // MARK: Tray contents

    /// Loose pieces in tray order, after the current filter.
    var trayPieces: [Int] {
        trayOrder.filter { index in
            guard !seated.contains(index) else { return false }
            switch trayFilter {
            case 1: return geometry.cut.isEdgePiece(index)
            case 2: return geometry.cut.isCornerPiece(index)
            default: return true
            }
        }
    }

    var looseCount: Int { pieceCount - seated.count }

    func shuffleTray() {
        var rng = JGRandom(seed: UInt64(Date().timeIntervalSince1970 * 1000) ^ seed)
        var order = trayOrder
        var i = order.count - 1
        while i > 0 {
            let j = rng.index(below: i + 1)
            order.swapAt(i, j)
            i -= 1
        }
        trayOrder = order
        shuffleStamp &+= 1
    }

    func availableFilterCount(_ filter: Int) -> Int {
        trayOrder.reduce(0) { total, index in
            guard !seated.contains(index) else { return total }
            switch filter {
            case 1: return total + (geometry.cut.isEdgePiece(index) ? 1 : 0)
            case 2: return total + (geometry.cut.isCornerPiece(index) ? 1 : 0)
            default: return total + 1
            }
        }
    }

    // MARK: Rotation

    func rotate(_ index: Int) {
        guard rotationMode, !seated.contains(index),
              index >= 0, index < rotations.count else { return }
        rotations[index] = (rotations[index] + 1) % 4
    }

    /// Turning rotation on scrambles only the pieces still loose; turning it off squares
    /// them all up again. Seated pieces are already home and are never touched.
    func setRotationMode(_ on: Bool) {
        guard rotationMode != on else { return }
        rotationMode = on
        var rng = JGRandom(seed: seed &+ UInt64(moves) &+ 77)
        for index in 0..<rotations.count where !seated.contains(index) {
            rotations[index] = on ? rng.index(below: 4) : 0
        }
    }

    func rotationOK(_ index: Int) -> Bool {
        guard rotationMode else { return true }
        guard index >= 0, index < rotations.count else { return true }
        return rotations[index] == 0
    }

    // MARK: Placing

    /// Distance in unit space at which a dropped piece is close enough to seat. Taken from
    /// the piece itself, so it scales with the cut instead of being a fixed number of points.
    func snapRadius(prefs: JGPrefs) -> CGFloat {
        geometry.snapRadius(fraction: prefs.snapFraction)
    }

    /// `point` is in unit space — one unit per cell, origin at the board's top-left corner.
    /// Returns true when the piece went home.
    @discardableResult
    func tryPlace(_ index: Int, atUnitPoint point: CGPoint, prefs: JGPrefs) -> Bool {
        moves += 1
        guard !finished, !seated.contains(index), rotationOK(index) else { return false }
        let home = geometry.unitHomeCentre(index)
        let dx = point.x - home.x
        let dy = point.y - home.y
        guard (dx * dx + dy * dy).squareRoot() <= snapRadius(prefs: prefs) else { return false }
        seat(index)
        return true
    }

    /// Seats a piece without spending a move — used by the hint.
    func seat(_ index: Int) {
        guard !seated.contains(index), index >= 0, index < pieceCount else { return }
        if index < rotations.count { rotations[index] = 0 }
        seated.insert(index)
        placedThisRun += 1
        lastSeated = index
        if selected == index { selected = nil }
        rebuildSeatedShapes()
        if seated.count == pieceCount {
            finished = true
            holdClock()
        }
    }

    /// Puts one correct piece down. Prefers whatever the player has singled out.
    @discardableResult
    func useHint() -> Int? {
        guard !finished else { return nil }
        var candidate: Int? = nil
        if let chosen = selected, !seated.contains(chosen) {
            candidate = chosen
        } else {
            // Edges first — that is the order a person would work in anyway.
            candidate = trayOrder.first { !seated.contains($0) && geometry.cut.isEdgePiece($0) }
                ?? trayOrder.first { !seated.contains($0) }
        }
        guard let index = candidate else { return nil }
        hintsUsed += 1
        seat(index)
        return index
    }

    private func rebuildSeatedShapes() {
        var union = Path()
        var seams = Path()
        for index in seated.sorted() where index < geometry.unitBoardPaths.count {
            union.addPath(geometry.unitBoardPaths[index])
            seams.addPath(geometry.unitBoardPaths[index])
        }
        seatedShape = union
        seatedSeams = seams
        seatedRevision &+= 1
    }

    // MARK: Persisting

    func snapshot() -> JGActivePuzzle {
        JGActivePuzzle(pictureID: picture.id,
                       tier: tier.id,
                       seed: seed,
                       seated: seated.sorted(),
                       rotations: rotations,
                       trayOrder: trayOrder,
                       elapsed: elapsed,
                       moves: moves,
                       hintsUsed: hintsUsed,
                       rotationMode: rotationMode,
                       ghostMode: ghostMode,
                       isDaily: isDaily,
                       dayKey: dayKey)
    }
}
