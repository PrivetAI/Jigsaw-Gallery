import SwiftUI

/// Everything that has been counted. All the plotting here is drawn by hand with `Path` and
/// `Canvas` — no charting framework is available on the deployment target and none is wanted.
struct JGStatsTab: View {

    @EnvironmentObject private var store: JGStore
    @State private var today = JGDaily.dayKey(for: Date())

    var body: some View {
        VStack(spacing: 0) {
            JGScreenHeader(title: "Record",
                           subtitle: "\(store.finishedConfigurationCount) of \(JGGalleryCatalog.configurationCount) cuts finished")
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    headlineBlock
                    tierBlock
                    collectionBlock
                    dailyBlock
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { today = JGDaily.dayKey(for: Date()) }
    }

    // MARK: Headline counts

    private var headlineBlock: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                figure("\(store.archive.puzzlesCompleted)", "puzzles finished")
                figure("\(store.archive.piecesPlaced)", "pieces placed")
                figure("\(store.unlockedPictureCount)", "pictures hung")
            }
            Rectangle().fill(JGPalette.cardEdge).frame(height: 1)
            HStack(spacing: 12) {
                JGStreakMark()
                    .fill(store.currentStreak(today: today) > 0 ? JGPalette.amber : JGPalette.cardEdge)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(streakLine)
                        .font(JGFont.title(14))
                        .foregroundColor(JGPalette.ink)
                    Text("The streak counts consecutive days of finishing the daily puzzle.")
                        .font(JGFont.body(11))
                        .foregroundColor(JGPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if store.archive.fastestSeconds > 0 {
                Rectangle().fill(JGPalette.cardEdge).frame(height: 1)
                HStack(spacing: 12) {
                    JGDialMark()
                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .foregroundColor(JGPalette.teal)
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Fastest finish · \(jgTimeText(store.archive.fastestSeconds))")
                            .font(JGFont.title(14))
                            .foregroundColor(JGPalette.ink)
                        Text(store.archive.fastestLabel)
                            .font(JGFont.body(11))
                            .foregroundColor(JGPalette.inkSoft)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 12) {
                JGSparkMark()
                    .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .foregroundColor(JGPalette.amber)
                    .frame(width: 20, height: 20)
                Text("\(store.archive.hints) hints in hand")
                    .font(JGFont.title(13))
                    .foregroundColor(JGPalette.ink)
                Spacer(minLength: 0)
                Text("+2 for every finish")
                    .font(JGFont.body(11))
                    .foregroundColor(JGPalette.inkSoft)
            }
        }
        .padding(14)
        .jgCard()
    }

    private var streakLine: String {
        let streak = store.currentStreak(today: today)
        if streak <= 0 { return "No streak running" }
        return streak == 1 ? "1 day streak" : "\(streak) day streak"
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(JGFont.display(22))
                .foregroundColor(JGPalette.tealDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(JGFont.body(10.5))
                .foregroundColor(JGPalette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Best time per cut

    private var tierBlock: some View {
        let entries = JGTiers.all.map { tier -> (JGTier, Double, String, Int) in
            let best = store.bestAtTier(tier)
            let finished = JGGalleryCatalog.pictures.reduce(0) {
                $0 + (store.archive.record(picture: $1.id, tier: tier.id).completed ? 1 : 0)
            }
            return (tier, best?.seconds ?? 0, best?.picture ?? "", finished)
        }
        let longest = entries.map { $0.1 }.max() ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Best time per cut")
                .font(JGFont.title(15))
                .foregroundColor(JGPalette.ink)
            ForEach(entries.indices, id: \.self) { index in
                let entry = entries[index]
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(entry.0.pieceCount)")
                            .font(JGFont.mono(12))
                            .foregroundColor(JGPalette.ink)
                            .frame(width: 30, alignment: .leading)
                        Text(entry.0.name)
                            .font(JGFont.body(12))
                            .foregroundColor(JGPalette.inkSoft)
                        Spacer(minLength: 4)
                        Text(entry.1 > 0 ? jgTimeText(entry.1) : "—")
                            .font(JGFont.mono(12))
                            .foregroundColor(entry.1 > 0 ? JGPalette.teal : JGPalette.inkFaint)
                    }
                    JGProgressRail(value: longest > 0 ? entry.1 / longest : 0,
                                   tone: JGPalette.teal, height: 6)
                    Text(entry.1 > 0
                         ? "\(entry.2) · \(entry.3) of \(JGGalleryCatalog.pictures.count) pictures done at this cut"
                         : "Not finished at this cut yet")
                        .font(JGFont.body(10.5))
                        .foregroundColor(JGPalette.inkFaint)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .jgCard()
    }

    // MARK: Progress by collection

    private var collectionBlock: some View {
        let bars = JGGalleryCatalog.collections.map { collection -> (String, Double, Int, Int) in
            let progress = store.collectionProgress(collection)
            let value = progress.total > 0 ? Double(progress.done) / Double(progress.total) : 0
            return (collection.name, value, progress.done, progress.total)
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("By collection")
                .font(JGFont.title(15))
                .foregroundColor(JGPalette.ink)
            JGColumnChart(bars: bars.map { ($0.0, $0.1) })
                .frame(height: 132)
            ForEach(bars.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Circle()
                        .fill(JGColumnChart.tone(index))
                        .frame(width: 8, height: 8)
                    Text(bars[index].0)
                        .font(JGFont.body(12))
                        .foregroundColor(JGPalette.inkSoft)
                    Spacer(minLength: 4)
                    Text("\(bars[index].2)/\(bars[index].3) cuts")
                        .font(JGFont.mono(11))
                        .foregroundColor(JGPalette.inkFaint)
                }
            }
        }
        .padding(14)
        .jgCard()
    }

    // MARK: Daily history

    private var dailyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily puzzle history")
                .font(JGFont.title(15))
                .foregroundColor(JGPalette.ink)
            if store.archive.dailyLog.isEmpty {
                Text("Nothing here yet. Finishing the puzzle of the day adds a line.")
                    .font(JGFont.body(12))
                    .foregroundColor(JGPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(store.archive.dailyLog.prefix(12))) { entry in
                    HStack(spacing: 10) {
                        Text(entry.day)
                            .font(JGFont.mono(11.5))
                            .foregroundColor(JGPalette.inkSoft)
                        Text(JGGalleryCatalog.picture(id: entry.pictureID)?.title ?? "Puzzle")
                            .font(JGFont.body(12))
                            .foregroundColor(JGPalette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(entry.tier)p")
                            .font(JGFont.mono(11))
                            .foregroundColor(JGPalette.inkFaint)
                        Text(jgTimeText(entry.seconds))
                            .font(JGFont.mono(11.5))
                            .foregroundColor(JGPalette.teal)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(14)
        .jgCard()
    }
}

/// A small column chart, drawn rather than imported.
struct JGColumnChart: View {
    let bars: [(String, Double)]

    /// One colour per collection, in catalog order. Long enough that no two collections
    /// share a dot at the sizes the catalog actually reaches; it wraps if it ever has to.
    private static let tones: [Color] = [JGPalette.teal, JGPalette.amber, JGPalette.rose,
                                         JGPalette.sage, JGPalette.clay, JGPalette.slate]

    static func tone(_ index: Int) -> Color {
        tones[((index % tones.count) + tones.count) % tones.count]
    }

    var body: some View {
        // The parent's height is honoured through the frame the caller sets; the canvas is
        // told its own box explicitly rather than trusting the closure's size for layout.
        GeometryReader { geo in
            Canvas { context, _ in
                let box = CGSize(width: geo.size.width, height: geo.size.height)
                guard box.width > 20, box.height > 20, !bars.isEmpty else { return }
                let baseline = box.height - 18
                let slot = box.width / CGFloat(bars.count)
                let barWidth = min(52, slot * 0.5)

                var grid = Path()
                for step in 0...4 {
                    let y = baseline - baseline * CGFloat(step) / 4
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: box.width, y: y))
                }
                context.stroke(grid, with: .color(JGPalette.cardEdge.opacity(0.7)), lineWidth: 1)

                for (index, bar) in bars.enumerated() {
                    let value = max(0, min(1, bar.1))
                    let height = max(2, baseline * CGFloat(value))
                    let x = slot * CGFloat(index) + (slot - barWidth) / 2
                    let rect = CGRect(x: x, y: baseline - height, width: barWidth, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: min(6, barWidth / 3)),
                                 with: .color(JGColumnChart.tone(index)))
                    let percent = Int((value * 100).rounded())
                    context.draw(Text("\(percent)%")
                                    .font(JGFont.mono(10))
                                    .foregroundColor(JGPalette.inkSoft),
                                 at: CGPoint(x: x + barWidth / 2, y: baseline + 9))
                }
            }
        }
    }
}
