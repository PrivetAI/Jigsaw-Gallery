import SwiftUI

struct JGSettingsTab: View {

    @EnvironmentObject private var store: JGStore
    @State private var showPrivacy = false
    @State private var askReset = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                JGScreenHeader(title: "Settings",
                               subtitle: "Defaults for every new board")
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        playBlock
                        feelBlock
                        aboutBlock
                        dangerBlock
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }

            if askReset { resetConfirm }
        }
        // One sheet on this view and no more: iOS 15 keeps only the last `.sheet` attached
        // to a given view, so a second one here would silently replace this.
        .sheet(isPresented: $showPrivacy) {
            JGPrivacySheet(isPresented: $showPrivacy)
        }
    }

    // MARK: Play defaults

    private var playBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New puzzles")
                .font(JGFont.title(15))
                .foregroundColor(JGPalette.ink)

            row(title: "Start with rotation",
                detail: "Pieces arrive at a random quarter turn and have to be turned square before they will seat.") {
                AnyView(JGSwitch(isOn: store.archive.prefs.rotationDefault) {
                    store.setRotationDefault(!store.archive.prefs.rotationDefault)
                    JGFeedback.tap(store.archive.prefs.haptics)
                })
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Reference image")
                    .font(JGFont.title(13))
                    .foregroundColor(JGPalette.ink)
                Text("How strongly the finished picture shows through the empty board. Currently \(store.archive.prefs.ghostName.lowercased()).")
                    .font(JGFont.body(11.5))
                    .foregroundColor(JGPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                JGSegments(options: ["Off", "Faint", "Full"],
                           selection: store.archive.prefs.ghostDefault) { value in
                    store.setGhostDefault(value)
                    JGFeedback.tap(store.archive.prefs.haptics)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Snap sensitivity")
                    .font(JGFont.title(13))
                    .foregroundColor(JGPalette.ink)
                Text("How near a piece has to land before it drops home. Measured against the piece, so it works the same at six pieces and at ninety-six.")
                    .font(JGFont.body(11.5))
                    .foregroundColor(JGPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                JGSegments(options: ["Tight", "Normal", "Forgiving"],
                           selection: store.archive.prefs.snapSensitivity) { value in
                    store.setSnapSensitivity(value)
                    JGFeedback.tap(store.archive.prefs.haptics)
                }
            }
        }
        .padding(14)
        .jgCard()
    }

    // MARK: Feel

    private var feelBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feel")
                .font(JGFont.title(15))
                .foregroundColor(JGPalette.ink)
            row(title: "Haptics",
                detail: "A small tap when a piece lifts and a firmer one when it seats.") {
                AnyView(JGSwitch(isOn: store.archive.prefs.haptics) {
                    // Read the new setting once. Reading it back off the store after writing
                    // and negating again fired a tap when they were switched OFF, and stayed
                    // silent when they were switched on.
                    let wanted = !store.archive.prefs.haptics
                    store.setHaptics(wanted)
                    JGFeedback.tap(wanted)
                })
            }
        }
        .padding(14)
        .jgCard()
    }

    // MARK: About

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(JGFont.title(15))
                .foregroundColor(JGPalette.ink)
            Text("Twelve painted pictures across three collections, each cut five ways, for sixty boards in all. Progress, times and the pieces you have placed are kept on this device only.")
                .font(JGFont.body(12))
                .foregroundColor(JGPalette.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { showPrivacy = true }) {
                HStack(spacing: 10) {
                    JGFrameMark()
                        .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        .foregroundColor(JGPalette.teal)
                        .frame(width: 18, height: 18)
                    Text("Privacy Policy")
                        .font(JGFont.title(14))
                        .foregroundColor(JGPalette.ink)
                    Spacer(minLength: 4)
                    JGChevron()
                        .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundColor(JGPalette.inkFaint)
                        .frame(width: 13, height: 13)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(JGPressStyle())

            HStack {
                Text("Version")
                    .font(JGFont.body(12))
                    .foregroundColor(JGPalette.inkSoft)
                Spacer(minLength: 4)
                Text("1.0")
                    .font(JGFont.mono(12))
                    .foregroundColor(JGPalette.inkFaint)
            }
        }
        .padding(14)
        .jgCard()
    }

    // MARK: Reset

    private var dangerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start over")
                .font(JGFont.title(15))
                .foregroundColor(JGPalette.ink)
            Text("Clears every finished cut, best time, hint and the puzzle currently on the table. There is no way back from this.")
                .font(JGFont.body(12))
                .foregroundColor(JGPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            JGWideButton(title: "Reset all progress", tone: JGPalette.rose) {
                askReset = true
            }
        }
        .padding(14)
        .jgCard()
    }

    private var resetConfirm: some View {
        ZStack {
            JGPalette.ink.opacity(0.55).edgesIgnoringSafeArea(.all)
            VStack(spacing: 14) {
                Text("Reset everything?")
                    .font(JGFont.display(20))
                    .foregroundColor(JGPalette.ink)
                Text("\(store.archive.puzzlesCompleted) finished puzzles and \(store.archive.piecesPlaced) placed pieces will be cleared. This cannot be undone.")
                    .font(JGFont.body(12.5))
                    .foregroundColor(JGPalette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                JGWideButton(title: "Yes, reset", tone: JGPalette.rose) {
                    store.resetEverything()
                    askReset = false
                }
                JGWideButton(title: "Keep my progress", tone: JGPalette.inkSoft) {
                    askReset = false
                }
            }
            .padding(20)
            .frame(maxWidth: 340)
            .jgCard()
            .padding(24)
        }
    }

    // MARK: Row scaffold

    private func row(title: String, detail: String,
                     control: () -> AnyView) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(JGFont.title(13))
                    .foregroundColor(JGPalette.ink)
                Text(detail)
                    .font(JGFont.body(11.5))
                    .foregroundColor(JGPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            control()
        }
    }
}

/// The privacy page, opened directly with no launch check of any kind.
struct JGPrivacySheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Privacy Policy")
                    .font(JGFont.title(15))
                    .foregroundColor(JGPalette.ink)
                Spacer(minLength: 8)
                JGRoundButton(glyph: JGCrossMark(), diameter: 34) { isPresented = false }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(JGPalette.card)
            .overlay(Rectangle().fill(JGPalette.cardEdge).frame(height: 1), alignment: .bottom)

            MosaicWebPanel(address: "https://crazytimeline.org")
                .edgesIgnoringSafeArea(.bottom)
        }
    }
}
