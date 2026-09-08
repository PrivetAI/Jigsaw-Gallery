import CoreGraphics
import Foundation

/// The board is always three wide by two tall, at every cut. That is what lets the shelf
/// preview, the gallery frame and the board itself all show the exact same crop of a picture.
/// Three of the five cuts divide it into perfect squares; the other two give pieces an eighth
/// wider than they are tall, which is well inside what a real cut board looks like.
let jgBoardUnits = CGSize(width: 3, height: 2)
let jgBoardAspect: CGFloat = jgBoardUnits.width / jgBoardUnits.height

/// One of the five cuts a picture can be given.
struct JGTier: Identifiable {
    let id: Int              // the piece count, which is also the stable storage key
    let columns: Int
    let rows: Int
    let name: String
    let blurb: String

    var pieceCount: Int { columns * rows }
}

enum JGTiers {
    static let all: [JGTier] = [
        JGTier(id: 6,  columns: 3,  rows: 2, name: "Opener",
               blurb: "Six big pieces. A minute, at most."),
        JGTier(id: 12, columns: 4,  rows: 3, name: "Light",
               blurb: "Twelve pieces. Enough to find a rhythm."),
        JGTier(id: 24, columns: 6,  rows: 4, name: "Steady",
               blurb: "Twenty-four pieces. Edges first starts to pay."),
        JGTier(id: 48, columns: 8,  rows: 6, name: "Long",
               blurb: "Forty-eight pieces. Sort by colour and settle in."),
        JGTier(id: 96, columns: 12, rows: 8, name: "Full Table",
               blurb: "Ninety-six pieces. The whole evening.")
    ]

    static func tier(for count: Int) -> JGTier {
        all.first(where: { $0.id == count }) ?? all[0]
    }

    static func index(of count: Int) -> Int {
        all.firstIndex(where: { $0.id == count }) ?? 0
    }
}

/// A picture in the gallery. `asset` is the image set name in the catalog.
struct JGPicture: Identifiable {
    let id: String
    let asset: String
    let title: String
    let collection: String
    let caption: String
}

struct JGCollection: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let pictures: [JGPicture]
}

enum JGGalleryCatalog {

    static let collections: [JGCollection] = [
        JGCollection(
            id: "coast",
            name: "Quiet Coast",
            blurb: "Four working shorelines, painted on days when nothing much was happening.",
            pictures: [
                JGPicture(
                    id: "coast.lowtide",
                    asset: "coastLowTide",
                    title: "Harbour at Low Tide",
                    collection: "Quiet Coast",
                    caption: "Twice a day the water leaves and the harbour turns into a yard. Boats that floated at breakfast now lean on their keels in the ribbed sand, and every rope, pot and float that was hidden underneath is suddenly on show. It is the only hour when you can walk out and look at the hulls properly."
                ),
                JGPicture(
                    id: "coast.tidepool",
                    asset: "coastTidePools",
                    title: "The Tide Pool",
                    collection: "Quiet Coast",
                    caption: "A pool the size of a kitchen table, left behind in the rock and busy with everything the tide forgot. Anemones close when a shadow crosses them, limpets hold on hard enough to leave a ring in the stone, and a crab reverses under the weed the moment you lean in. Stand still for a minute and the whole thing starts moving again."
                ),
                JGPicture(
                    id: "coast.lighthouse",
                    asset: "coastLighthouse",
                    title: "Lighthouse Meadow",
                    collection: "Quiet Coast",
                    caption: "The tower gets all the attention, but the walk out to it is the good part. Thrift and gorse grow low and tough against the wind, the wall runs on long after it stops being useful, and the ledges below are packed with birds that ignore you entirely. The light itself only matters after dark."
                ),
                JGPicture(
                    id: "coast.boatyard",
                    asset: "coastBoatyard",
                    title: "The Boat Yard",
                    collection: "Quiet Coast",
                    caption: "A yard where nothing is thrown away in case it comes in useful, and it always does. Hulls wait upside down for their turn, timber is stacked by length rather than by grade, and the shed wall carries thirty years of floats hung up on nails. Everything here has been repaired at least once."
                )
            ]
        ),
        JGCollection(
            id: "wood",
            name: "Woodland Hours",
            blurb: "Four pieces of forest, each painted at the height of its own season.",
            pictures: [
                JGPicture(
                    id: "wood.leaffall",
                    asset: "woodLeafFall",
                    title: "Leaf Fall",
                    collection: "Woodland Hours",
                    caption: "The floor of an old wood a week after the first hard frost, when the leaves come down faster than anything can rot them. Acorns and chestnuts sit on top of the drift, toadstools push through it, and something small has already made a tunnel under the whole lot. Every colour here is a shade of the same three."
                ),
                JGPicture(
                    id: "wood.birch",
                    asset: "woodBirchDeer",
                    title: "Birch and Mist",
                    collection: "Woodland Hours",
                    caption: "Birches keep their distance from one another, so the mist has room to sit between the trunks until the sun gets high enough to burn it off. Two deer stand in it long enough to be certain about you, then move off without hurrying. The bark reads white from far away and about nine colours from close up."
                ),
                JGPicture(
                    id: "wood.stream",
                    asset: "woodStream",
                    title: "The Shallow Stream",
                    collection: "Woodland Hours",
                    caption: "Barely deep enough to cover a boot, and loud out of all proportion to its size. Ferns crowd right to the lip of both banks, a fallen trunk has been the bridge long enough to grow its own moss, and a kingfisher works the same three perches all morning. The stones underneath are every colour the water makes them."
                ),
                JGPicture(
                    id: "wood.oak",
                    asset: "woodHollowOak",
                    title: "The Hollow Oak",
                    collection: "Woodland Hours",
                    caption: "Hollow for a century and in no hurry about it, this oak is now more a building than a tree. Squirrels use the ivy as a staircase, an owl has the upper room, and bracket fungus steps out of the trunk in shelves wide enough to sit on. The acorns still come down every autumn, by the thousand."
                )
            ]
        ),
        JGCollection(
            id: "city",
            name: "City at Dusk",
            blurb: "Four city scenes caught in the half hour when the lamps beat the daylight.",
            pictures: [
                JGPicture(
                    id: "city.rooftops",
                    asset: "cityRooftops",
                    title: "Above the Rooftops",
                    collection: "City at Dusk",
                    caption: "Old cities keep their clutter on the roof: chimney pots by the dozen, aerials nobody has taken down, water tanks, skylights, and a washing line strung between two of them. At dusk the windows behind start lighting one at a time in no particular order. The pigeons treat all of it as level ground."
                ),
                JGPicture(
                    id: "city.tram",
                    asset: "cityTramStreet",
                    title: "The Tram Street",
                    collection: "City at Dusk",
                    caption: "A street narrow enough that the tram and the shopfront awnings have to negotiate. Bicycles lean where the railings are, planters take up the rest, and every upper window has put something on its ledge. The cobbles hold the last of the wet from the afternoon and hand the lamplight straight back."
                ),
                JGPicture(
                    id: "city.market",
                    asset: "cityNightMarket",
                    title: "The Night Market",
                    collection: "City at Dusk",
                    caption: "Seen from the walkway above the stalls, where the canopies overlap into one striped roof with the lanterns hung underneath it. Crates go out full and come back empty all evening, and the stacking is done by whoever gets there first. Nothing matches and it all works."
                ),
                JGPicture(
                    id: "city.bridge",
                    asset: "cityRiverBridge",
                    title: "The Iron Bridge",
                    collection: "City at Dusk",
                    caption: "The ironwork was made ornamental because that is simply how bridges were made then, and a century later nobody would dare simplify it. Barges tie up along the quay below, the steps down are worn into a curve, and the whole thing arrives twice — once in the air and once in the water. Dusk is when the two versions match."
                )
            ]
        )
    ]

    static let pictures: [JGPicture] = collections.flatMap { $0.pictures }

    static func picture(id: String) -> JGPicture? {
        pictures.first(where: { $0.id == id })
    }

    static func collection(containing pictureID: String) -> JGCollection? {
        collections.first(where: { $0.pictures.contains(where: { $0.id == pictureID }) })
    }

    /// Total number of (picture, tier) pairs — 12 pictures across 5 cuts.
    static var configurationCount: Int { pictures.count * JGTiers.all.count }
}

// MARK: - Daily puzzle

/// The picture and cut for one calendar day, chosen from the date alone so every launch on
/// the same day lands on the same puzzle.
struct JGDailyPick {
    let dayKey: String
    let picture: JGPicture
    let tier: JGTier
    let seed: UInt64
}

enum JGDaily {

    /// `yyyy-MM-dd` in the device's own calendar. Written by hand rather than with a
    /// DateFormatter so it cannot drift with locale settings.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2026, parts.month ?? 1, parts.day ?? 1)
    }

    static func pick(for date: Date, calendar: Calendar = .current) -> JGDailyPick {
        let key = dayKey(for: date, calendar: calendar)
        let seed = jgStableSeed("jigsaw.daily." + key)
        var rng = JGRandom(seed: seed)
        let pictures = JGGalleryCatalog.pictures
        let picture = pictures[rng.index(below: pictures.count)]
        // Weighted so the middle cuts come up most often and 96 stays a rarity.
        let ladder = [6, 12, 12, 24, 24, 24, 48, 48, 96]
        let count = ladder[rng.index(below: ladder.count)]
        return JGDailyPick(dayKey: key,
                           picture: picture,
                           tier: JGTiers.tier(for: count),
                           seed: seed)
    }

    /// Yesterday's key, used to decide whether a streak survives.
    static func previousKey(of key: String, calendar: Calendar = .current) -> String? {
        let bits = key.split(separator: "-").compactMap { Int($0) }
        guard bits.count == 3 else { return nil }
        var components = DateComponents()
        components.year = bits[0]
        components.month = bits[1]
        components.day = bits[2]
        guard let date = calendar.date(from: components),
              let previous = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        return dayKey(for: previous, calendar: calendar)
    }
}
