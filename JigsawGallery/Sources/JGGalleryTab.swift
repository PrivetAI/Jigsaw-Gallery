import SwiftUI

/// Finished pictures, hung and captioned. Everything still unfinished is a silhouette, so
/// the shelf keeps a reason to go back to it.
struct JGGalleryTab: View {

    @EnvironmentObject private var store: JGStore

    var body: some View {
        VStack(spacing: 0) {
            JGScreenHeader(title: "Gallery",
                           subtitle: "\(store.unlockedPictureCount) of \(JGGalleryCatalog.pictures.count) pictures hung")
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 22) {
                    ForEach(JGGalleryCatalog.collections) { collection in
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(collection.name)
                                    .font(JGFont.display(19))
                                    .foregroundColor(JGPalette.ink)
                                Text(collection.blurb)
                                    .font(JGFont.body(12))
                                    .foregroundColor(JGPalette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(collection.pictures) { picture in
                                if store.archive.isUnlocked(picture: picture.id) {
                                    hungFrame(picture)
                                } else {
                                    silhouette(picture)
                                }
                            }
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

    private func hungFrame(_ picture: JGPicture) -> some View {
        let best = bestTime(for: picture)
        return VStack(alignment: .leading, spacing: 0) {
            // The mount: an outer frame band, then the picture, the way it would actually hang.
            JGPicturePlate(asset: picture.asset, corner: 4)
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(JGPalette.paper))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(JGPalette.feltEdge, lineWidth: 2))
                .padding(8)

            VStack(alignment: .leading, spacing: 6) {
                Text(picture.title)
                    .font(JGFont.title(16))
                    .foregroundColor(JGPalette.ink)
                Text(picture.caption)
                    .font(JGFont.body(12.5))
                    .foregroundColor(JGPalette.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    JGTierPips(completed: store.archive.completedTierCount(picture: picture.id))
                    if let best = best {
                        Text("best \(jgTimeText(best.time)) at \(best.pieces) pieces")
                            .font(JGFont.mono(10.5))
                            .foregroundColor(JGPalette.inkFaint)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .padding(.top, 2)
        }
        .jgCard()
    }

    private func silhouette(_ picture: JGPicture) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(JGPalette.felt)
                JGSilhouettePattern()
                    .stroke(JGPalette.feltRule, lineWidth: 1)
                VStack(spacing: 8) {
                    JGLockMark()
                        .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        .foregroundColor(JGPalette.feltEdge)
                        .frame(width: 26, height: 26)
                    Text("Not yet finished")
                        .font(JGFont.title(12))
                        .foregroundColor(JGPalette.feltEdge)
                }
            }
            .aspectRatio(jgBoardAspect, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(JGPalette.feltEdge.opacity(0.6), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(picture.title)
                    .font(JGFont.title(14))
                    .foregroundColor(JGPalette.inkSoft)
                Text("Finish any cut of this picture to hang it here.")
                    .font(JGFont.body(11.5))
                    .foregroundColor(JGPalette.inkFaint)
            }
        }
        .padding(12)
        .jgCard()
    }

    private func bestTime(for picture: JGPicture) -> (time: Double, pieces: Int)? {
        var found: (Double, Int)? = nil
        for tier in JGTiers.all {
            let record = store.archive.record(picture: picture.id, tier: tier.id)
            guard record.completed, record.bestSeconds > 0 else { continue }
            // The most pieces finished is the more interesting claim; ties go to the faster run.
            if found == nil || tier.pieceCount > found!.1 {
                found = (record.bestSeconds, tier.pieceCount)
            }
        }
        guard let value = found else { return nil }
        return (value.0, value.1)
    }
}

/// A loose lattice of jigsaw seams, drawn behind a locked frame so the empty plate still
/// reads as a puzzle rather than a missing image.
struct JGSilhouettePattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columns = 6
        let rows = 4
        let cellWidth = rect.width / CGFloat(columns)
        let cellHeight = rect.height / CGFloat(rows)
        let bump = min(cellWidth, cellHeight) * 0.16

        for column in 1..<columns {
            let x = rect.minX + CGFloat(column) * cellWidth
            for row in 0..<rows {
                let top = rect.minY + CGFloat(row) * cellHeight
                let mid = top + cellHeight / 2
                let out: CGFloat = (column + row) % 2 == 0 ? 1 : -1
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x, y: mid - bump))
                path.addCurve(to: CGPoint(x: x, y: mid + bump),
                              control1: CGPoint(x: x + out * bump * 2.2, y: mid - bump),
                              control2: CGPoint(x: x + out * bump * 2.2, y: mid + bump))
                path.addLine(to: CGPoint(x: x, y: top + cellHeight))
            }
        }
        for row in 1..<rows {
            let y = rect.minY + CGFloat(row) * cellHeight
            for column in 0..<columns {
                let left = rect.minX + CGFloat(column) * cellWidth
                let mid = left + cellWidth / 2
                let out: CGFloat = (column + row) % 2 == 0 ? -1 : 1
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: mid - bump, y: y))
                path.addCurve(to: CGPoint(x: mid + bump, y: y),
                              control1: CGPoint(x: mid - bump, y: y + out * bump * 2.2),
                              control2: CGPoint(x: mid + bump, y: y + out * bump * 2.2))
                path.addLine(to: CGPoint(x: left + cellWidth, y: y))
            }
        }
        return path
    }
}
