import SwiftUI

/// The app itself. No `NavigationView` anywhere: every screen change is a piece of state, so
/// there is no nav bar to hide, no pushed view that cannot be dismissed, and no system
/// chrome to work around.
struct JGRootView: View {

    @EnvironmentObject private var store: JGStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab = 0
    @State private var launch: JGLaunch? = nil
    /// Held while the player decides. Exactly ONE puzzle is kept in progress, so opening a
    /// different one throws the saved board away — it used to do that in silence.
    @State private var pendingLaunch: JGLaunch? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                JGPalette.paper.edgesIgnoringSafeArea(.all)

                // The tab bar is the last row of a VStack rather than a floating overlay,
                // so it can never sit on top of the final rows of a scroll view.
                VStack(spacing: 0) {
                    Group {
                        switch tab {
                        case 0:
                            JGShelfTab(onPlay: { requested in
                                // Resuming the saved board, or starting one with nothing
                                // to lose, goes straight through. Anything else would
                                // discard real progress, so it asks first.
                                if requested.resume == nil, let saved = store.resumable,
                                   !(saved.pictureID == requested.picture.id
                                     && saved.tier == requested.tier.id) {
                                    pendingLaunch = requested
                                } else {
                                    launch = requested
                                }
                            })
                        case 1:
                            JGGalleryTab()
                        case 2:
                            JGStatsTab()
                        default:
                            JGSettingsTab()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    tabBar
                }

                if let live = launch {
                    JGPuzzleView(launch: live,
                                 prefs: store.archive.prefs,
                                 onExit: { launch = nil },
                                 onReplace: { next in
                                     launch = nil
                                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                         launch = next
                                     }
                                 })
                        .id(live.id)
                        .transition(.opacity)
                }

                // Opaque strip over the status bar, added LAST so no scrolling content can
                // ever be drawn across the clock.
                VStack(spacing: 0) {
                    JGPalette.card.frame(height: geo.safeAreaInsets.top)
                    Spacer(minLength: 0)
                }
                .edgesIgnoringSafeArea(.top)
                .allowsHitTesting(false)
            }
        }
        .confirmationDialog("A puzzle is already in progress",
                            isPresented: Binding(get: { pendingLaunch != nil },
                                                 set: { if !$0 { pendingLaunch = nil } }),
                            titleVisibility: .visible) {
            Button("Discard it and start this one", role: .destructive) {
                let next = pendingLaunch
                pendingLaunch = nil
                if let next = next {
                    store.clearActive()
                    launch = next
                }
            }
            Button("Cancel", role: .cancel) { pendingLaunch = nil }
        } message: {
            Text(discardWarning)
        }
        .onChange(of: scenePhase) { phase in
            // Only `.background` writes. `.inactive` fires on the way in as well, and a save
            // taken there stamps a state the app is about to leave anyway.
            if phase == .background { store.flush() }
        }
    }

    /// Names the board that would be lost, so the choice is not an abstract one.
    private var discardWarning: String {
        guard let saved = store.resumable else { return "" }
        let seated = saved.seated.count
        let title = JGGalleryCatalog.picture(id: saved.pictureID)?.title ?? "your saved puzzle"
        if seated > 0 {
            return "Starting this one clears \u{201C}\(title)\u{201D}, where \(seated) "
                + (seated == 1 ? "piece is" : "pieces are") + " already placed."
        }
        return "Starting this one clears the board you left in \u{201C}\(title)\u{201D}."
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            // Stroked, not bare. A `Shape` used straight as a view is FILLED, and these
            // glyphs are outlines — filling them turns every tab icon into a solid blob.
            tabButton(0, "Puzzles", AnyView(JGGlyphView(shape: JGQuadMark())))
            tabButton(1, "Gallery", AnyView(JGGlyphView(shape: JGFrameMark())))
            tabButton(2, "Record", AnyView(JGGlyphView(shape: JGColumnsMark())))
            tabButton(3, "Settings", AnyView(JGGlyphView(shape: JGSlidersMark())))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            VStack(spacing: 0) {
                Rectangle().fill(JGPalette.cardEdge).frame(height: 1)
                JGPalette.card
            }
            .edgesIgnoringSafeArea(.bottom)
        )
    }

    private func tabButton(_ index: Int, _ title: String, _ glyph: AnyView) -> some View {
        Button(action: {
            tab = index
            JGFeedback.tap(store.archive.prefs.haptics)
        }) {
            VStack(spacing: 3) {
                glyph
                    .frame(width: 24, height: 24)
                    .foregroundColor(tab == index ? JGPalette.teal : JGPalette.inkFaint)
                Text(title)
                    .font(JGFont.title(10))
                    .foregroundColor(tab == index ? JGPalette.teal : JGPalette.inkFaint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(JGPressStyle())
    }
}

/// Draws a glyph as an outline and takes its colour from the surrounding foreground style,
/// so it can be passed around as an `AnyView` and still tint with the tab it belongs to.
struct JGGlyphView<S: Shape>: View {
    let shape: S
    var lineWidth: CGFloat = 1.7

    var body: some View {
        shape.stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

/// A screen title bar shared by every tab, with an optional back arrow.
struct JGScreenHeader: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let onBack = onBack {
                JGRoundButton(glyph: JGChevron(facing: 1), diameter: 38) { onBack() }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(JGFont.display(21))
                    .foregroundColor(JGPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(JGFont.body(12))
                        .foregroundColor(JGPalette.inkSoft)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(JGPalette.card)
        .overlay(Rectangle().fill(JGPalette.cardEdge).frame(height: 1), alignment: .bottom)
    }
}
