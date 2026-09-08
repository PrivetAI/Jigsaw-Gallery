import SwiftUI

/// The picture as it will be cut — the same three-by-two crop the board uses, so what you
/// pick is what you assemble.
struct JGPicturePlate: View {
    let asset: String
    var corner: CGFloat = 12
    var body: some View {
        Color.clear
            .aspectRatio(jgBoardAspect, contentMode: .fit)
            .overlay(
                Image(asset)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(JGPalette.cardEdge, lineWidth: 1)
            )
    }
}

/// Five pips, one per cut, filled in as each is finished.
struct JGTierPips: View {
    let completed: Int
    var tone: Color = JGPalette.teal
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<JGTiers.all.count, id: \.self) { index in
                Circle()
                    .fill(index < completed ? tone : JGPalette.cardEdge)
                    .frame(width: 6, height: 6)
            }
        }
    }
}

/// The browsing tab: what is half finished, what today's puzzle is, and the three shelves.
struct JGShelfTab: View {

    @EnvironmentObject private var store: JGStore
    let onPlay: (JGLaunch) -> Void

    @State private var detail: JGPicture? = nil

    var body: some View {
        Group {
            if let picture = detail {
                JGPictureDetail(picture: picture,
                                onBack: { detail = nil },
                                onPlay: onPlay)
            } else {
                shelf
            }
        }
    }

    private var shelf: some View {
        VStack(spacing: 0) {
            JGScreenHeader(title: "Jigsaw Gallery",
                           subtitle: "12 pictures · 5 cuts each · \(store.finishedConfigurationCount) of \(JGGalleryCatalog.configurationCount) done")
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    if let saved = store.resumable { resumeCard(saved) }
                    dailyCard
                    ForEach(JGGalleryCatalog.collections) { collection in
                        collectionBlock(collection)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Resume

    private func resumeCard(_ saved: JGActivePuzzle) -> some View {
        let picture = JGGalleryCatalog.picture(id: saved.pictureID)
        let tier = JGTiers.tier(for: saved.tier)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let picture = picture {
                    JGPicturePlate(asset: picture.asset, corner: 9)
                        .frame(width: 96)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Still on the table")
                        .font(JGFont.body(11))
                        .foregroundColor(JGPalette.amber)
                    Text(picture?.title ?? "A puzzle")
                        .font(JGFont.title(15))
                        .foregroundColor(JGPalette.ink)
                        .lineLimit(2)
                    Text("\(saved.seated.count) of \(tier.pieceCount) placed · \(jgTimeText(saved.elapsed))")
                        .font(JGFont.body(11))
                        .foregroundColor(JGPalette.inkSoft)
                }
                Spacer(minLength: 0)
            }
            JGProgressRail(value: tier.pieceCount == 0 ? 0
                           : Double(saved.seated.count) / Double(tier.pieceCount),
                           tone: JGPalette.amber)
            HStack(spacing: 10) {
                JGWideButton(title: "Carry on", tone: JGPalette.amber) {
                    guard let picture = picture else { return }
                    onPlay(JGLaunch(picture: picture, tier: tier, seed: saved.seed,
                                    isDaily: saved.isDaily, dayKey: saved.dayKey,
                                    resume: saved))
                }
                Button(action: { store.clearActive() }) {
                    Text("Clear")
                        .font(JGFont.title(14))
                        .foregroundColor(JGPalette.inkSoft)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(JGPalette.cardEdge, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(JGPressStyle())
            }
        }
        .padding(14)
        .jgCard()
    }

    // MARK: Daily

    private var dailyCard: some View {
        let pick = JGDaily.pick(for: Date())
        let solved = store.dailySolved(day: pick.dayKey)
        let streak = store.currentStreak(today: pick.dayKey)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                JGDayMark()
                    .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .foregroundColor(JGPalette.tealDeep)
                    .frame(width: 20, height: 20)
                Text("Puzzle of the Day")
                    .font(JGFont.title(15))
                    .foregroundColor(JGPalette.ink)
                Spacer(minLength: 0)
                if streak > 0 {
                    HStack(spacing: 4) {
                        JGStreakMark()
                            .fill(JGPalette.amber)
                            .frame(width: 13, height: 13)
                        Text("\(streak)")
                            .font(JGFont.title(13))
                            .foregroundColor(JGPalette.amber)
                    }
                }
            }

            HStack(spacing: 12) {
                JGPicturePlate(asset: pick.picture.asset, corner: 9)
                    .frame(width: 110)
                VStack(alignment: .leading, spacing: 3) {
                    Text(pick.picture.title)
                        .font(JGFont.title(14))
                        .foregroundColor(JGPalette.ink)
                        .lineLimit(2)
                    Text("\(pick.tier.pieceCount) pieces · \(pick.tier.name)")
                        .font(JGFont.body(11))
                        .foregroundColor(JGPalette.inkSoft)
                    Text(pick.dayKey)
                        .font(JGFont.mono(11))
                        .foregroundColor(JGPalette.inkFaint)
                }
                Spacer(minLength: 0)
            }

            if let done = solved {
                HStack(spacing: 8) {
                    JGTickMark()
                        .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .foregroundColor(JGPalette.teal)
                        .frame(width: 15, height: 15)
                    Text("Finished today in \(jgTimeText(done.seconds))")
                        .font(JGFont.body(12))
                        .foregroundColor(JGPalette.teal)
                    Spacer(minLength: 0)
                }
                JGWideButton(title: "Do it again", tone: JGPalette.inkSoft) {
                    startDaily(pick, asDaily: false)
                }
            } else {
                JGWideButton(title: "Start today's puzzle",
                             subtitle: pick.tier.blurb,
                             tone: JGPalette.tealDeep) {
                    startDaily(pick, asDaily: true)
                }
            }

            weekStrip(upTo: pick.dayKey)
        }
        .padding(14)
        .jgCard()
    }

    private func startDaily(_ pick: JGDailyPick, asDaily: Bool) {
        onPlay(JGLaunch(picture: pick.picture,
                        tier: pick.tier,
                        seed: asDaily ? pick.seed : pick.seed &+ 9_781,
                        isDaily: asDaily,
                        dayKey: asDaily ? pick.dayKey : "",
                        resume: nil))
    }

    /// The last seven days, filled in where the daily was finished.
    private func weekStrip(upTo key: String) -> some View {
        var days: [String] = [key]
        var cursor = key
        for _ in 0..<6 {
            guard let previous = JGDaily.previousKey(of: cursor) else { break }
            days.append(previous)
            cursor = previous
        }
        let ordered = days.reversed().map { $0 }
        return HStack(spacing: 5) {
            ForEach(ordered, id: \.self) { day in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(store.dailySolved(day: day) != nil ? JGPalette.teal : JGPalette.cardEdge)
                    .frame(height: 8)
            }
        }
    }

    // MARK: Collections

    private func collectionBlock(_ collection: JGCollection) -> some View {
        let progress = store.collectionProgress(collection)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(collection.name)
                    .font(JGFont.display(18))
                    .foregroundColor(JGPalette.ink)
                Spacer(minLength: 6)
                Text("\(progress.done)/\(progress.total)")
                    .font(JGFont.mono(12))
                    .foregroundColor(JGPalette.inkSoft)
            }
            Text(collection.blurb)
                .font(JGFont.body(12))
                .foregroundColor(JGPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            JGProgressRail(value: progress.total == 0 ? 0
                           : Double(progress.done) / Double(progress.total))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(collection.pictures) { picture in
                    pictureCard(picture)
                }
            }
        }
        .padding(14)
        .jgCard()
    }

    private func pictureCard(_ picture: JGPicture) -> some View {
        Button(action: { detail = picture }) {
            VStack(alignment: .leading, spacing: 6) {
                JGPicturePlate(asset: picture.asset, corner: 10)
                Text(picture.title)
                    .font(JGFont.title(12))
                    .foregroundColor(JGPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                JGTierPips(completed: store.archive.completedTierCount(picture: picture.id))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JGPressStyle())
    }
}

// MARK: - One picture, five cuts

struct JGPictureDetail: View {

    @EnvironmentObject private var store: JGStore
    let picture: JGPicture
    let onBack: () -> Void
    let onPlay: (JGLaunch) -> Void

    var body: some View {
        VStack(spacing: 0) {
            JGScreenHeader(title: picture.title,
                           subtitle: picture.collection,
                           onBack: onBack)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    JGPicturePlate(asset: picture.asset, corner: 14)
                    Text(picture.caption)
                        .font(JGFont.body(13))
                        .foregroundColor(JGPalette.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Choose a cut")
                        .font(JGFont.title(15))
                        .foregroundColor(JGPalette.ink)

                    VStack(spacing: 10) {
                        ForEach(JGTiers.all) { tier in
                            tierRow(tier)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func tierRow(_ tier: JGTier) -> some View {
        let record = store.archive.record(picture: picture.id, tier: tier.id)
        let saved = savedRun(for: tier)
        return Button(action: { start(tier, saved: saved) }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(record.completed ? JGPalette.tealWash : JGPalette.paper)
                    Text("\(tier.pieceCount)")
                        .font(JGFont.display(17))
                        .foregroundColor(record.completed ? JGPalette.tealDeep : JGPalette.ink)
                }
                .frame(width: 54, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tier.name)
                            .font(JGFont.title(14))
                            .foregroundColor(JGPalette.ink)
                        if record.completed {
                            JGTickMark()
                                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .foregroundColor(JGPalette.teal)
                                .frame(width: 12, height: 12)
                        }
                        if saved != nil {
                            Text("in progress")
                                .font(JGFont.body(10))
                                .foregroundColor(JGPalette.amber)
                        }
                    }
                    Text(tier.blurb)
                        .font(JGFont.body(11))
                        .foregroundColor(JGPalette.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if record.bestSeconds > 0 {
                        Text("best \(jgTimeText(record.bestSeconds)) · finished \(record.completions) time\(record.completions == 1 ? "" : "s")")
                            .font(JGFont.mono(10))
                            .foregroundColor(JGPalette.inkFaint)
                    }
                }
                Spacer(minLength: 4)
                JGChevron()
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundColor(JGPalette.inkFaint)
                    .frame(width: 14, height: 14)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(JGPalette.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(JGPalette.cardEdge, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(JGPressStyle())
    }

    /// A half-finished run only counts if it is this very picture at this very cut.
    private func savedRun(for tier: JGTier) -> JGActivePuzzle? {
        guard let saved = store.resumable,
              saved.pictureID == picture.id, saved.tier == tier.id else { return nil }
        return saved
    }

    private func start(_ tier: JGTier, saved: JGActivePuzzle?) {
        if let saved = saved {
            onPlay(JGLaunch(picture: picture, tier: tier, seed: saved.seed,
                            isDaily: saved.isDaily, dayKey: saved.dayKey, resume: saved))
        } else {
            onPlay(JGLaunch(picture: picture, tier: tier,
                            seed: jgStableSeed("\(picture.id)#\(tier.id)"),
                            isDaily: false, dayKey: "", resume: nil))
        }
    }
}
