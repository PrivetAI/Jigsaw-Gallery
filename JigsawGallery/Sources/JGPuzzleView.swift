import SwiftUI

enum JGSpace {
    static let name = "jigsaw.board.space"
}

/// Reports the board viewport's frame in the puzzle screen's own coordinate space, so a
/// finger position taken anywhere on screen can be turned into a board position.
struct JGBoardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// The playing screen: board above, tray below in portrait and alongside in landscape.
struct JGPuzzleView: View {

    @EnvironmentObject private var store: JGStore
    @StateObject private var session: JGSession
    @Environment(\.scenePhase) private var scenePhase

    let onExit: () -> Void
    let onReplace: (JGLaunch) -> Void

    // Camera
    @State private var zoom: CGFloat = 1
    @State private var zoomAnchor: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panAnchor: CGSize = .zero
    @State private var boardFrame: CGRect = .zero

    // The piece under the finger
    @State private var carried: Int? = nil
    @State private var carriedPoint: CGPoint = .zero

    // Feedback
    @State private var flashCentre: CGPoint = .zero
    @State private var flashAmount: Double = 0
    @State private var recorded = false
    @State private var newBest = false
    @State private var showNoHints = false

    init(launch: JGLaunch, prefs: JGPrefs,
         onExit: @escaping () -> Void,
         onReplace: @escaping (JGLaunch) -> Void) {
        _session = StateObject(wrappedValue: JGSession(launch: launch, prefs: prefs))
        self.onExit = onExit
        self.onReplace = onReplace
    }

    var body: some View {
        GeometryReader { outer in
            let landscape = outer.size.width > outer.size.height
            let tight = outer.size.height < 660
            ZStack(alignment: .topLeading) {
                JGPalette.paper.edgesIgnoringSafeArea(.all)

                if landscape {
                    // Landscape has no room for a separate tool row, so the header carries
                    // the tools instead. It must never do both, or every control appears
                    // twice on the same screen.
                    VStack(spacing: 0) {
                        header(compact: true, carriesTools: true)
                        HStack(spacing: 0) {
                            boardSection
                            trayBlock(vertical: true, height: outer.size.height)
                                .frame(width: 148)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        header(compact: tight, carriesTools: false)
                        toolbar
                        boardSection
                        trayBlock(vertical: false, height: outer.size.height)
                    }
                }

                // The piece being carried rides above everything, so it is never clipped by
                // the tray or the board viewport.
                if let index = carried {
                    let square = session.rotationOK(index)
                    JGLoosePiece(asset: session.picture.asset,
                                 index: index,
                                 geometry: session.geometry,
                                 scale: carriedScale,
                                 quarterTurns: session.rotations.indices.contains(index)
                                     ? session.rotations[index] : 0,
                                 highlighted: true,
                                 // A piece that is still turned cannot seat anywhere, so it
                                 // says so rather than just quietly refusing to drop.
                                 highlightTone: square ? JGPalette.amber : JGPalette.rose)
                        .position(x: carriedPoint.x, y: carriedPoint.y - carriedLift)
                        .allowsHitTesting(false)
                    if !square {
                        Text("Tap the piece to turn it square")
                            .font(JGFont.body(11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(JGPalette.rose.opacity(0.94)))
                            .position(x: min(max(carriedPoint.x, 110), outer.size.width - 110),
                                      y: max(30, carriedPoint.y - carriedLift - carriedBadgeGap))
                            .allowsHitTesting(false)
                    }
                }

                if session.paused && !session.finished { pauseSheet }
                if session.finished { finishSheet }
                if showNoHints { hintsExhaustedNote }
            }
            .coordinateSpace(name: JGSpace.name)
            .onPreferenceChange(JGBoardFrameKey.self) { boardFrame = $0 }
        }
        .onAppear { session.resumeClock() }
        .onDisappear { session.holdClock() }
        .onChange(of: session.finished) { done in
            if done { completePuzzle() }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                session.resumeClock()
            case .background:
                // The last dependable moment before the process can be killed. `.inactive`
                // is deliberately not a save point — it fires on the way in as well.
                session.holdClock()
                store.storeActive(session.finished ? nil : session.snapshot())
                // Credit what has been placed as well. Without this, a process killed from
                // the switcher loses every piece put down since the board was opened.
                store.creditLoosePieces(session.takePlacedCredit())
                store.flush()
            default:
                session.holdClock()
            }
        }
    }

    // MARK: - Header

    private func header(compact: Bool, carriesTools: Bool) -> some View {
        HStack(spacing: 10) {
            JGRoundButton(glyph: JGChevron(facing: 1), diameter: compact ? 36 : 40) {
                leave()
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(session.picture.title)
                    .font(JGFont.title(compact ? 14 : 15))
                    .foregroundColor(JGPalette.ink)
                    .lineLimit(1)
                Text(session.isDaily
                     ? "Daily · \(session.tier.pieceCount) pieces"
                     : "\(session.tier.name) · \(session.tier.pieceCount) pieces")
                    .font(JGFont.body(11))
                    .foregroundColor(JGPalette.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                JGClockReadout(session: session)
                Text("\(session.placedCount)/\(session.pieceCount) · \(session.moves) moves")
                    .font(JGFont.body(10))
                    .foregroundColor(JGPalette.inkSoft)
                    .lineLimit(1)
            }
            if carriesTools { compactToolbar }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 6 : 9)
        .background(JGPalette.card)
        .overlay(Rectangle().fill(JGPalette.cardEdge).frame(height: 1), alignment: .bottom)
    }

    /// The same four controls the portrait tool row offers, as icons.
    private var compactToolbar: some View {
        HStack(spacing: 5) {
            JGRoundButton(glyph: JGLayersMark(), diameter: 34,
                          tint: session.ghostMode > 0 ? JGPalette.teal : JGPalette.inkSoft) {
                cycleGhost()
            }
            JGRoundButton(glyph: JGTurnMark(), diameter: 34,
                          tint: session.rotationMode ? JGPalette.teal : JGPalette.inkSoft) {
                session.setRotationMode(!session.rotationMode)
                JGFeedback.tap(store.archive.prefs.haptics)
            }
            JGRoundButton(glyph: JGSparkMark(), diameter: 34,
                          tint: store.archive.hints > 0 ? JGPalette.amber : JGPalette.inkFaint,
                          enabled: store.archive.hints > 0 && !session.finished) {
                spendHint()
            }
            JGRoundButton(glyph: JGPauseMark(), diameter: 34) { session.setPaused(true) }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            JGPillButton(glyph: JGLayersMark(),
                         title: ghostTitle,
                         active: session.ghostMode > 0) { cycleGhost() }
            JGPillButton(glyph: JGTurnMark(),
                         title: session.rotationMode ? "Turning" : "Square",
                         active: session.rotationMode) {
                session.setRotationMode(!session.rotationMode)
                JGFeedback.tap(store.archive.prefs.haptics)
            }
            JGPillButton(glyph: JGSparkMark(),
                         title: "Hint \(store.archive.hints)",
                         active: false,
                         enabled: store.archive.hints > 0 && !session.finished) { spendHint() }
            Spacer(minLength: 0)
            JGRoundButton(glyph: JGPauseMark(), diameter: 36) { session.setPaused(true) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(JGPalette.paper)
    }

    private var ghostTitle: String {
        switch session.ghostMode {
        case 0: return "Guide off"
        case 2: return "Guide full"
        default: return "Guide faint"
        }
    }

    // MARK: - Board

    private var boardSection: some View {
        GeometryReader { geo in
            let camera = camera(for: geo.size)
            ZStack(alignment: .topLeading) {
                JGBoardLayer(asset: session.picture.asset,
                             unitSize: session.boardUnitSize,
                             unitScale: camera.scale,
                             cellSize: session.cellUnitSize,
                             boardOrigin: camera.origin,
                             viewport: geo.size,
                             seatedShape: session.seatedShape,
                             seatedSeams: session.seatedSeams,
                             seatedRevision: session.seatedRevision,
                             ghostMode: session.ghostMode,
                             flashCentre: flashCentre,
                             flashAmount: flashAmount)
                    .equatable()

                if let target = snapTarget(camera: camera) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(JGPalette.amber, lineWidth: 2.5)
                        .frame(width: session.cellUnitSize.width * camera.scale,
                               height: session.cellUnitSize.height * camera.scale)
                        .offset(x: target.x, y: target.y)
                        .allowsHitTesting(false)
                }

                // A way back out of a zoom, so nobody has to pinch their way home.
                if zoom > 1.02 {
                    HStack {
                        Spacer(minLength: 0)
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.22)) {
                                zoom = 1
                                zoomAnchor = 1
                                pan = .zero
                                panAnchor = .zero
                            }
                        }) {
                            Text("Fit")
                                .font(JGFont.title(12))
                                .foregroundColor(JGPalette.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(JGPalette.card.opacity(0.94)))
                                .overlay(Capsule().stroke(JGPalette.cardEdge, lineWidth: 1))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(JGPressStyle())
                    }
                    .padding(10)
                    .frame(width: geo.size.width, alignment: .topTrailing)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(panGesture(viewport: geo.size))
            .simultaneousGesture(zoomGesture(viewport: geo.size))
            .clipped()
            .background(
                GeometryReader { probe in
                    Color.clear.preference(key: JGBoardFrameKey.self,
                                           value: probe.frame(in: .named(JGSpace.name)))
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Points per unit and the board's top-left corner inside the viewport.
    private func camera(for viewport: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        let scale = baseScale(for: viewport) * zoom
        let width = jgBoardUnits.width * scale
        let height = jgBoardUnits.height * scale
        let slackX = max(0, (width - viewport.width) / 2)
        let slackY = max(0, (height - viewport.height) / 2)
        let dx = min(max(pan.width, -slackX), slackX)
        let dy = min(max(pan.height, -slackY), slackY)
        return (scale, CGPoint(x: (viewport.width - width) / 2 + dx,
                               y: (viewport.height - height) / 2 + dy))
    }

    /// The scale at which the whole board just fits. Inscribed with `min()` and never floored
    /// to a minimum — a board that cannot fit its viewport spills over whatever is beside it.
    private func baseScale(for viewport: CGSize) -> CGFloat {
        let usable = CGSize(width: max(40, viewport.width - 18),
                            height: max(40, viewport.height - 18))
        return min(usable.width / jgBoardUnits.width, usable.height / jgBoardUnits.height)
    }

    private func panGesture(viewport: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                pan = CGSize(width: panAnchor.width + value.translation.width,
                             height: panAnchor.height + value.translation.height)
                clampPan(viewport: viewport)
            }
            .onEnded { _ in
                clampPan(viewport: viewport)
                panAnchor = pan
            }
    }

    private func zoomGesture(viewport: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(4, max(1, zoomAnchor * value))
                clampPan(viewport: viewport)
            }
            .onEnded { _ in
                zoomAnchor = zoom
                clampPan(viewport: viewport)
                panAnchor = pan
            }
    }

    /// Keeps the board inside the viewport whatever the zoom does, so it can never be
    /// pushed off screen and lost.
    private func clampPan(viewport: CGSize) {
        let scale = baseScale(for: viewport) * zoom
        let slackX = max(0, (jgBoardUnits.width * scale - viewport.width) / 2)
        let slackY = max(0, (jgBoardUnits.height * scale - viewport.height) / 2)
        pan = CGSize(width: min(max(pan.width, -slackX), slackX),
                     height: min(max(pan.height, -slackY), slackY))
    }

    /// Where the carried piece would land, in the board viewport's coordinates, when it is
    /// close enough to seat. nil the rest of the time.
    private func snapTarget(camera: (scale: CGFloat, origin: CGPoint)) -> CGPoint? {
        guard let index = carried, camera.scale > 0 else { return nil }
        guard session.rotationOK(index) else { return nil }
        let unit = unitPoint(for: carriedPoint, camera: camera)
        let home = session.geometry.unitHomeCentre(index)
        let dx = unit.x - home.x
        let dy = unit.y - home.y
        guard (dx * dx + dy * dy).squareRoot() <= session.snapRadius(prefs: store.archive.prefs) else {
            return nil
        }
        let cell = session.cellUnitSize
        return CGPoint(x: camera.origin.x + (home.x - cell.width / 2) * camera.scale,
                       y: camera.origin.y + (home.y - cell.height / 2) * camera.scale)
    }

    /// Screen point (in the puzzle screen's space) to board unit space.
    private func unitPoint(for screenPoint: CGPoint,
                           camera: (scale: CGFloat, origin: CGPoint)) -> CGPoint {
        let centre = CGPoint(x: screenPoint.x, y: screenPoint.y - carriedLift)
        let local = CGPoint(x: centre.x - boardFrame.minX, y: centre.y - boardFrame.minY)
        return CGPoint(x: (local.x - camera.origin.x) / camera.scale,
                       y: (local.y - camera.origin.y) / camera.scale)
    }

    /// The carried piece is drawn at board size so it reads as the piece that will land.
    private var carriedScale: CGFloat {
        guard boardFrame.width > 0 else { return session.geometry.scaleForCell(52) }
        return camera(for: boardFrame.size).scale
    }

    /// Lifted clear of the fingertip, or the piece is invisible underneath it.
    private var carriedLift: CGFloat {
        let cell = max(session.geometry.cellWidth, session.geometry.cellHeight) * carriedScale
        return min(54, max(24, cell * 0.8))
    }

    /// Distance from the carried piece's centre to the note above it.
    private var carriedBadgeGap: CGFloat {
        max(session.geometry.cellWidth, session.geometry.cellHeight) * carriedScale * 0.75 + 18
    }

    // MARK: - Tray

    /// A three-by-two board leaves real room under it in portrait, so the tray takes two lanes
    /// wherever the screen can afford them and falls back to one when it cannot.
    ///
    /// The tray is capped at a share of what is left after the header and the tool row, not
    /// just at a flat number. A fixed tray on a short screen is what squeezes the flexible
    /// child above it down to nothing.
    private func trayLayout(vertical: Bool, height: CGFloat) -> (cell: CGFloat, lanes: Int, block: CGFloat) {
        if vertical { return (42, 2, 0) }
        let available = max(120, height - 100)
        if available >= 620 { return (52, 2, min(206, available * 0.42)) }
        if available >= 480 { return (44, 2, min(176, available * 0.42)) }
        return (38, 1, min(104, max(74, available * 0.36)))
    }

    private func trayBlock(vertical: Bool, height: CGFloat) -> some View {
        let layout = trayLayout(vertical: vertical, height: height)
        return VStack(spacing: 0) {
            trayFilters(vertical: vertical)
            JGTrayStrip(session: session,
                        cell: layout.cell,
                        lanes: layout.lanes,
                        vertical: vertical,
                        carried: carried,
                        onLiftChanged: { index, value in liftChanged(index, value) },
                        onLiftEnded: { index, value in liftEnded(index, value) },
                        onTap: { index in trayTapped(index) })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: vertical ? nil : layout.block)
        .background(JGPalette.tray)
        .overlay(Rectangle().fill(JGPalette.trayEdge)
                    .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1),
                 alignment: vertical ? .leading : .top)
    }

    @ViewBuilder
    private func trayFilters(vertical: Bool) -> some View {
        // Three chips plus a shuffle will not fit across a narrow side tray, so landscape
        // stacks them into two rows rather than squeezing every label into nothing.
        if vertical {
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    filterChip(0, "All")
                    filterChip(1, "Edges")
                }
                HStack(spacing: 5) {
                    filterChip(2, "Corners")
                    JGRoundButton(glyph: JGShuffleMark(), diameter: 26, lineWidth: 1.6,
                                  fill: JGPalette.card) {
                        session.shuffleTray()
                        JGFeedback.tap(store.archive.prefs.haptics)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 7)
            .padding(.bottom, 3)
        } else {
            HStack(spacing: 6) {
                filterChip(0, "All")
                filterChip(1, "Edges")
                filterChip(2, "Corners")
                Spacer(minLength: 0)
                JGRoundButton(glyph: JGShuffleMark(), diameter: 28, lineWidth: 1.6,
                              fill: JGPalette.card) {
                    session.shuffleTray()
                    JGFeedback.tap(store.archive.prefs.haptics)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 7)
            .padding(.bottom, 3)
        }
    }

    private func filterChip(_ value: Int, _ title: String) -> some View {
        let count = session.availableFilterCount(value)
        return Button(action: { session.trayFilter = value }) {
            Text("\(title) \(count)")
                .font(JGFont.title(11))
                .foregroundColor(session.trayFilter == value ? .white : JGPalette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(session.trayFilter == value ? JGPalette.tealDeep : JGPalette.card)
                )
                .overlay(Capsule().stroke(JGPalette.trayEdge, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(JGPressStyle())
    }

    private func liftChanged(_ index: Int, _ value: DragGesture.Value) {
        if carried != index {
            carried = index
            session.selected = index
            JGFeedback.tap(store.archive.prefs.haptics)
        }
        carriedPoint = value.location
    }

    private func liftEnded(_ index: Int, _ value: DragGesture.Value) {
        carriedPoint = value.location
        dropCarried(index)
        carried = nil
    }

    private func trayTapped(_ index: Int) {
        if session.rotationMode {
            session.rotate(index)
            JGFeedback.tap(store.archive.prefs.haptics)
        } else {
            session.selected = session.selected == index ? nil : index
        }
    }

    private func dropCarried(_ index: Int) {
        guard boardFrame.width > 0 else { return }
        let cam = camera(for: boardFrame.size)
        let unit = unitPoint(for: carriedPoint, camera: cam)
        let seated = session.tryPlace(index, atUnitPoint: unit, prefs: store.archive.prefs)
        if seated {
            flash(at: session.geometry.unitHomeCentre(index))
            JGFeedback.seat(store.archive.prefs.haptics)
            if !session.finished {
                store.storeActive(session.snapshot())
            }
        }
    }

    private func flash(at unitCentre: CGPoint) {
        flashCentre = unitCentre
        flashAmount = 0.001
        withAnimation(.easeOut(duration: 0.45)) { flashAmount = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            if flashAmount >= 1 { flashAmount = 0 }
        }
    }

    // MARK: - Actions

    private func cycleGhost() {
        session.ghostMode = (session.ghostMode + 1) % 3
        JGFeedback.tap(store.archive.prefs.haptics)
    }

    private func spendHint() {
        guard !session.finished else { return }
        guard store.spendHint() else {
            showNoHints = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { showNoHints = false }
            return
        }
        if let index = session.useHint() {
            flash(at: session.geometry.unitHomeCentre(index))
            JGFeedback.seat(store.archive.prefs.haptics)
            if !session.finished { store.storeActive(session.snapshot()) }
        }
    }

    private func leave() {
        session.holdClock()
        if !session.finished {
            store.storeActive(session.snapshot())
        }
        store.creditLoosePieces(session.takePlacedCredit())
        onExit()
    }

    private func completePuzzle() {
        guard !recorded else { return }
        recorded = true
        session.holdClock()
        newBest = store.recordFinish(picture: session.picture,
                                     tier: session.tier,
                                     seconds: session.elapsed,
                                     piecesPlacedThisRun: session.takePlacedCredit(),
                                     isDaily: session.isDaily,
                                     dayKey: session.dayKey)
        JGFeedback.finish(store.archive.prefs.haptics)
    }

    // MARK: - Overlays

    private var pauseSheet: some View {
        ZStack {
            JGPalette.ink.opacity(0.55).edgesIgnoringSafeArea(.all)
            VStack(spacing: 16) {
                Text("Paused")
                    .font(JGFont.display(24))
                    .foregroundColor(JGPalette.ink)
                Text("\(session.placedCount) of \(session.pieceCount) pieces placed · \(jgTimeText(session.elapsed))")
                    .font(JGFont.body(13))
                    .foregroundColor(JGPalette.inkSoft)
                    .multilineTextAlignment(.center)
                JGWideButton(title: "Resume") { session.setPaused(false) }
                JGWideButton(title: "Leave and keep progress",
                             tone: JGPalette.inkSoft) { leave() }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .jgCard()
            .padding(24)
        }
    }

    private var finishSheet: some View {
        ZStack {
            JGPalette.ink.opacity(0.62).edgesIgnoringSafeArea(.all)
            VStack(spacing: 14) {
                Text("Finished")
                    .font(JGFont.display(26))
                    .foregroundColor(JGPalette.ink)
                Text(session.picture.title)
                    .font(JGFont.title(15))
                    .foregroundColor(JGPalette.teal)
                    .multilineTextAlignment(.center)

                HStack(spacing: 0) {
                    finishStat(jgTimeText(session.elapsed), "time")
                    finishStat("\(session.pieceCount)", "pieces")
                    finishStat("\(session.moves)", "moves")
                    finishStat("\(session.hintsUsed)", "hints")
                }

                if newBest {
                    Text("New best time for this cut")
                        .font(JGFont.title(12))
                        .foregroundColor(JGPalette.amber)
                }

                JGWideButton(title: "Back to the shelf") { onExit() }
                if let next = nextTier {
                    JGWideButton(title: "Try \(next.pieceCount) pieces",
                                 subtitle: next.name,
                                 tone: JGPalette.tealDeep) {
                        onReplace(JGLaunch(picture: session.picture,
                                           tier: next,
                                           seed: jgStableSeed(session.picture.id + "#\(next.id)"),
                                           isDaily: false,
                                           dayKey: "",
                                           resume: nil))
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 360)
            .jgCard()
            .padding(20)
        }
    }

    private func finishStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(JGFont.title(16))
                .foregroundColor(JGPalette.ink)
            Text(label)
                .font(JGFont.body(10))
                .foregroundColor(JGPalette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private var nextTier: JGTier? {
        let index = JGTiers.index(of: session.tier.id)
        guard index + 1 < JGTiers.all.count else { return nil }
        return JGTiers.all[index + 1]
    }

    private var hintsExhaustedNote: some View {
        VStack {
            Spacer()
            Text("No hints left. Finish a puzzle to earn two more.")
                .font(JGFont.body(12))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(JGPalette.ink.opacity(0.9)))
                .padding(.bottom, 150)
        }
        .allowsHitTesting(false)
    }
}

/// Its own view so the ticking clock redraws one label rather than the whole screen.
struct JGClockReadout: View {
    @ObservedObject var session: JGSession
    @State private var shown: Double = 0
    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(jgTimeText(shown))
            .font(JGFont.mono(15))
            .foregroundColor(JGPalette.ink)
            .onReceive(ticker) { _ in shown = session.elapsed }
            .onAppear { shown = session.elapsed }
    }
}
