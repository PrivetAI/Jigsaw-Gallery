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

/// Spells a small number out in words, so the prose in Settings can quote the catalog's
/// own counts without anyone having to retype "twelve" the next time a picture is added.
/// Pinned to en_US because the app ships in English only; the digits are the fallback.
func jgSpelledNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    formatter.locale = Locale(identifier: "en_US")
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

func jgSpelledNumberCapitalised(_ value: Int) -> String {
    let word = jgSpelledNumber(value)
    return word.prefix(1).uppercased() + word.dropFirst()
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
            blurb: "Six working shorelines, painted on days when nothing much was happening.",
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
                ),
                JGPicture(
                    id: "coast.pier",
                    asset: "coastPierLamps",
                    title: "The Long Pier",
                    collection: "Quiet Coast",
                    caption: "Built for the boats and used by everybody else. The lamps come on before they are needed, the boards give under you in the same three places every time, and the pots stacked along the rail belong to whoever put them there. Once the sun is properly down the gulls have the whole thing to themselves."
                ),
                JGPicture(
                    id: "coast.marsh",
                    asset: "coastSaltMarsh",
                    title: "The Salt Marsh",
                    collection: "Quiet Coast",
                    caption: "Neither land nor water, and it changes its mind twice a day. The creeks fill from the bottom up so quickly that a channel you stepped over in the morning wants a boat by lunchtime. Sea lavender holds the banks together, the birds work the mud for whatever the tide left behind, and the staithe is the only straight line in it."
                )
            ]
        ),
        JGCollection(
            id: "wood",
            name: "Woodland Hours",
            blurb: "Six pieces of forest, each painted at the height of its own season.",
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
                ),
                JGPicture(
                    id: "wood.bluebells",
                    asset: "woodBluebells",
                    title: "Bluebell Morning",
                    collection: "Woodland Hours",
                    caption: "The whole show lasts about three weeks and is finished before the beech leaves are properly out, which is the arrangement the bluebells have made. They come up through last year's litter in numbers that make no sense, hold the colour for a fortnight, then go back underground for eleven months. On a still morning you smell them before you see them."
                ),
                JGPicture(
                    id: "wood.summer",
                    asset: "woodSummerCanopy",
                    title: "Full Summer",
                    collection: "Woodland Hours",
                    caption: "By July the canopy has closed and the wood keeps its own weather underneath: cooler, greener and about two stops darker than the field outside. Foxgloves take the gaps where a tree came down and brambles take everything else. The light arrives in coins that move all afternoon and never quite land on the path."
                )
            ]
        ),
        JGCollection(
            id: "city",
            name: "City at Dusk",
            blurb: "Six city scenes caught in the half hour when the lamps beat the daylight.",
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
                    caption: "The ironwork was made ornamental because that is simply how bridges were made then, and a century later nobody would dare simplify it. Barges tie up along the quay below, the steps down are worn into a curve, and the whole thing arrives twice, once in the air and once in the water. Dusk is when the two versions match."
                ),
                JGPicture(
                    id: "city.canal",
                    asset: "cityCanalHouses",
                    title: "The Canal Houses",
                    collection: "City at Dusk",
                    caption: "Built narrow because the frontage was taxed, and tall because the family had to go somewhere. The gables lean out over the water so furniture can be swung up past a staircase that was never going to take it. At dusk the row appears twice, and the version in the water is the tidier of the two."
                ),
                JGPicture(
                    id: "city.parkgate",
                    asset: "cityParkGate",
                    title: "The Park Gate",
                    collection: "City at Dusk",
                    caption: "The gate is shut at dusk and the lamps inside stay lit for another hour, which appears to be nobody's decision in particular. Rain earlier has put a shine on the path and stuck the leaves down flat, so the light runs all the way to the fountain in two long smears. The benches are wet and will stay wet until Thursday."
                )
            ]
        ),
        JGCollection(
            id: "peak",
            name: "High and Quiet",
            blurb: "Six days above the last wall, where the weather turns up before you hear it.",
            pictures: [
                JGPicture(
                    id: "peak.tarn",
                    asset: "peakColdTarn",
                    title: "The Cold Tarn",
                    collection: "High and Quiet",
                    caption: "Held in a hollow the ice left behind, fed by not much and drained by less. The far end is deep enough to stay the same temperature all year, which is to say too cold, and the near end is clear enough to count the stones. Somebody built the cairn on the spur and somebody else has been adding to it ever since."
                ),
                JGPicture(
                    id: "peak.fold",
                    asset: "peakSheepFold",
                    title: "The Sheep Fold",
                    collection: "High and Quiet",
                    caption: "A round wall built without mortar by someone who knew exactly how many stones he had. The sheep use it in bad weather and ignore it the rest of the time, which is the whole arrangement. The walls running off over the fell are older than the hut and will outlast it."
                ),
                JGPicture(
                    id: "peak.scree",
                    asset: "peakScreePath",
                    title: "The Scree Path",
                    collection: "High and Quiet",
                    caption: "It is only a path because enough people picked the same line up a slope that is otherwise loose the whole way down. Every cairn on it was built by somebody who was glad of the excuse to stop. Flowers get a hold where the stones have settled, and the marmots watch the procession from the one boulder that never moves."
                ),
                JGPicture(
                    id: "peak.meadow",
                    asset: "peakAlpineMeadow",
                    title: "The Alpine Meadow",
                    collection: "High and Quiet",
                    caption: "Cut once a year, in a fortnight the weather decides rather than the calendar. Left alone until then, it does this: forty kinds of flower in a field that spends half its life under snow. The barn has stones on the roof because the wind up here has opinions about shingles."
                ),
                JGPicture(
                    id: "peak.bothy",
                    asset: "peakStoneBothy",
                    title: "The Bothy",
                    collection: "High and Quiet",
                    caption: "Two rooms, a chimney and a door that shuts properly, which at this height counts as luxury. Nobody owns it and everybody looks after it, so you leave the wood you did not burn and sweep the floor on the way out. The cloud sitting in the corrie below will lift by six or not at all."
                ),
                JGPicture(
                    id: "peak.ridge",
                    asset: "peakRidgeSunrise",
                    title: "First Light on the Ridge",
                    collection: "High and Quiet",
                    caption: "The sun finds the tops a good half hour before it reaches the valleys, so for a while the ridge is in the morning and everything under it is still last night. The pines up here grow sideways because sideways is the only direction left. Frost goes off the rock the moment the light touches it."
                )
            ]
        ),
        JGCollection(
            id: "farm",
            name: "Field and Lane",
            blurb: "Six pieces of working country, painted in the weeks when it all happens at once.",
            pictures: [
                JGPicture(
                    id: "farm.harvest",
                    asset: "farmHarvestField",
                    title: "The Last Field",
                    collection: "Field and Lane",
                    caption: "Cutting starts at the outside and works inwards, so the standing wheat gets smaller all afternoon until there is none of it left. The stubble is sharp enough to go through a boot, and the straw is baled the same evening if the forecast is being honest. Poppies survive along the margin because nobody has ever bothered to plough it."
                ),
                JGPicture(
                    id: "farm.orchard",
                    asset: "farmOldOrchard",
                    title: "The Old Orchard",
                    collection: "Field and Lane",
                    caption: "Old trees, planted far enough apart that a horse could turn between them, which tells you roughly when. Half of what comes off them goes into crates and the other half stays on the grass for the hens and the wasps. The ladder has been in that fork since Tuesday and will still be there on Friday."
                ),
                JGPicture(
                    id: "farm.mill",
                    asset: "farmMillPond",
                    title: "The Mill Pond",
                    collection: "Field and Lane",
                    caption: "The pond is not really a pond, it is an afternoon of water kept in hand, dammed so the wheel has something to turn on the days the stream cannot manage alone. The wheel goes round about once every four seconds and drips for ten minutes after it stops. Lilies do well in the still corner and ducks do well everywhere."
                ),
                JGPicture(
                    id: "farm.lane",
                    asset: "farmHedgerowLane",
                    title: "The Hedgerow Lane",
                    collection: "Field and Lane",
                    caption: "Sunk a little lower every century by cartwheels and rain, until the banks came up to shoulder height on their own. Cow parsley takes the top of them in June and everything else fights over what is left. The grass strip down the middle survives because no wheel has ever run in the middle."
                ),
                JGPicture(
                    id: "farm.barn",
                    asset: "farmBarnDoor",
                    title: "The Barn Door",
                    collection: "Field and Lane",
                    caption: "Open at both ends when the weather allows, which is what the through draught was for long before anyone called it ventilation. The tools on the wall are hung by whoever used them last and are therefore in the wrong order. The cat has the beam, the dog has the floor, and that was settled years ago."
                ),
                JGPicture(
                    id: "farm.lavender",
                    asset: "farmLavenderRows",
                    title: "Lavender Rows",
                    collection: "Field and Lane",
                    caption: "Planted in rows wide enough for a machine that comes twice a year and is resented the rest of the time. In the fortnight before cutting the whole field hums loudly enough to hear from the gate. The stone holds the afternoon heat until well after dark, which is the point of building in it."
                )
            ]
        ),
        JGCollection(
            id: "snow",
            name: "Deep Winter",
            blurb: "Six villages in the fortnight when snow stops being news and becomes the arrangement.",
            pictures: [
                JGPicture(
                    id: "snow.lane",
                    asset: "snowVillageLane",
                    title: "The Village Lane",
                    collection: "Deep Winter",
                    caption: "The lane is cleared by whoever is up first, on a rota nobody has ever written down. Snow lying that deep on a roof is a good sign rather than a bad one: it means the heat is staying inside where it was put. The sledge by the door is transport at least half the time."
                ),
                JGPicture(
                    id: "snow.bridge",
                    asset: "snowCoveredBridge",
                    title: "The Covered Bridge",
                    collection: "Deep Winter",
                    caption: "Roofed because a deck lasts eight times as long out of the weather, and for no more romantic reason than that. The river below is frozen at the edges and running black down the middle, which is exactly as far as it should be trusted. One set of footprints going in, none yet coming out."
                ),
                JGPicture(
                    id: "snow.cabin",
                    asset: "snowPineCabin",
                    title: "The Pine Cabin",
                    collection: "Deep Winter",
                    caption: "Built low and squat so the drifts go over it rather than through it, with the woodpile stacked where it can be reached without putting boots on. Snow sits on a pine branch until it does not, and then the whole load comes off at once. The lantern is lit early because up here the afternoon gives up around three."
                ),
                JGPicture(
                    id: "snow.canal",
                    asset: "snowFrozenCanal",
                    title: "The Frozen Canal",
                    collection: "Deep Winter",
                    caption: "Once it is thick enough the canal stops being a barrier and becomes the shortest way to everywhere. Skate lines run where the boats went in summer, and all the bridges are suddenly in the wrong place. The low sun never clears the roofs after two, so the ice keeps whatever it was given in the morning."
                ),
                JGPicture(
                    id: "snow.market",
                    asset: "snowMarketSquare",
                    title: "The Winter Market",
                    collection: "Deep Winter",
                    caption: "Stalls that go up in one afternoon and come down in another, and are treated as permanent for the six weeks in between. Snow is swept off the canvas twice a day and off the cobbles about once. Everything is lit from a foot away, which is why the square looks warm and is not."
                ),
                JGPicture(
                    id: "snow.aurora",
                    asset: "snowNightLights",
                    title: "Lights Over the Valley",
                    collection: "Deep Winter",
                    caption: "It happens on the clearest nights, which are also the coldest, so it is never free. The green comes and goes on a schedule of its own and does it in complete silence, which surprises people who expected otherwise. Down in the valley the windows stay lit and mostly nobody looks up."
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

    /// Total number of (picture, tier) pairs: every picture at every cut.
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

    /// `yyyy-MM-dd`, always Gregorian. Written by hand rather than with a DateFormatter,
    /// and pinned to a fixed calendar rather than `.current`: in a Thai or Buddhist-locale
    /// region `.current` is the Buddhist calendar, which printed 2026 as "2569" on the
    /// main screen and shifted every stored key the moment the user changed region.
    static let keyCalendar = Calendar(identifier: .gregorian)

    static func dayKey(for date: Date, calendar: Calendar = keyCalendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2026, parts.month ?? 1, parts.day ?? 1)
    }

    static func pick(for date: Date, calendar: Calendar = keyCalendar) -> JGDailyPick {
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
    static func previousKey(of key: String, calendar: Calendar = keyCalendar) -> String? {
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
