import CoreGraphics
import Foundation

// Every stored type decodes field by field with `decodeIfPresent` and a default. A future
// version can then add a field without the synthesised decoder throwing on the missing key
// and silently wiping somebody's whole gallery.

/// What has been done with one (picture, cut) pair.
struct JGRecord: Codable {
    var completed: Bool
    var bestSeconds: Double     // 0 means "never finished"
    var completions: Int

    init(completed: Bool = false, bestSeconds: Double = 0, completions: Int = 0) {
        self.completed = completed
        self.bestSeconds = bestSeconds
        self.completions = completions
    }

    enum CodingKeys: String, CodingKey { case completed, bestSeconds, completions }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? box.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        completed = value(.completed, false)
        bestSeconds = value(.bestSeconds, 0)
        completions = value(.completions, 0)
    }
}

/// One line in the daily puzzle's own little history.
struct JGDailyEntry: Codable, Identifiable {
    var day: String
    var pictureID: String
    var tier: Int
    var completed: Bool
    var seconds: Double

    var id: String { day }

    init(day: String, pictureID: String, tier: Int, completed: Bool, seconds: Double) {
        self.day = day
        self.pictureID = pictureID
        self.tier = tier
        self.completed = completed
        self.seconds = seconds
    }

    enum CodingKeys: String, CodingKey { case day, pictureID, tier, completed, seconds }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? box.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        day = value(.day, "")
        pictureID = value(.pictureID, "")
        tier = value(.tier, 12)
        completed = value(.completed, false)
        seconds = value(.seconds, 0)
    }
}

/// A puzzle left half-finished. Restoring one puts every loose piece back where it was, with
/// the same clock, the same cut and the same tray order.
struct JGActivePuzzle: Codable {
    var pictureID: String
    var tier: Int
    var seed: UInt64
    var seated: [Int]
    var rotations: [Int]
    var trayOrder: [Int]
    var elapsed: Double
    var moves: Int
    var hintsUsed: Int
    var rotationMode: Bool
    var ghostMode: Int
    var isDaily: Bool
    var dayKey: String

    init(pictureID: String, tier: Int, seed: UInt64, seated: [Int], rotations: [Int],
         trayOrder: [Int], elapsed: Double, moves: Int, hintsUsed: Int,
         rotationMode: Bool, ghostMode: Int, isDaily: Bool, dayKey: String) {
        self.pictureID = pictureID
        self.tier = tier
        self.seed = seed
        self.seated = seated
        self.rotations = rotations
        self.trayOrder = trayOrder
        self.elapsed = elapsed
        self.moves = moves
        self.hintsUsed = hintsUsed
        self.rotationMode = rotationMode
        self.ghostMode = ghostMode
        self.isDaily = isDaily
        self.dayKey = dayKey
    }

    enum CodingKeys: String, CodingKey {
        case pictureID, tier, seed, seated, rotations, trayOrder
        case elapsed, moves, hintsUsed, rotationMode, ghostMode, isDaily, dayKey
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? box.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        pictureID = value(.pictureID, "")
        tier = value(.tier, 12)
        seed = value(.seed, UInt64(1))
        seated = value(.seated, [Int]())
        rotations = value(.rotations, [Int]())
        trayOrder = value(.trayOrder, [Int]())
        elapsed = value(.elapsed, 0)
        moves = value(.moves, 0)
        hintsUsed = value(.hintsUsed, 0)
        rotationMode = value(.rotationMode, false)
        ghostMode = value(.ghostMode, 1)
        isDaily = value(.isDaily, false)
        dayKey = value(.dayKey, "")
    }
}

/// The four things Settings can change.
struct JGPrefs: Codable {
    var rotationDefault: Bool
    var ghostDefault: Int        // 0 off · 1 faint · 2 full
    var snapSensitivity: Int     // 0 tight · 1 normal · 2 forgiving
    var haptics: Bool

    init(rotationDefault: Bool = false, ghostDefault: Int = 1,
         snapSensitivity: Int = 1, haptics: Bool = true) {
        self.rotationDefault = rotationDefault
        self.ghostDefault = ghostDefault
        self.snapSensitivity = snapSensitivity
        self.haptics = haptics
    }

    enum CodingKeys: String, CodingKey {
        case rotationDefault, ghostDefault, snapSensitivity, haptics
    }

    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? box.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        rotationDefault = value(.rotationDefault, false)
        ghostDefault = value(.ghostDefault, 1)
        snapSensitivity = value(.snapSensitivity, 1)
        haptics = value(.haptics, true)
    }

    /// Snap radius as a fraction of one piece's edge.
    var snapFraction: CGFloat {
        switch snapSensitivity {
        case 0: return 0.30
        case 2: return 0.62
        default: return 0.44
        }
    }

    var snapName: String {
        switch snapSensitivity {
        case 0: return "Tight"
        case 2: return "Forgiving"
        default: return "Normal"
        }
    }

    var ghostName: String {
        switch ghostDefault {
        case 0: return "Off"
        case 2: return "Full"
        default: return "Faint"
        }
    }
}

/// Everything the app remembers, in one blob.
struct JGArchive: Codable {
    var records: [String: JGRecord]
    var piecesPlaced: Int
    var puzzlesCompleted: Int
    var fastestSeconds: Double
    var fastestLabel: String
    var streakCount: Int
    var streakDay: String
    var hints: Int
    var prefs: JGPrefs
    var active: JGActivePuzzle?
    var dailyLog: [JGDailyEntry]

    init() {
        records = [:]
        piecesPlaced = 0
        puzzlesCompleted = 0
        fastestSeconds = 0
        fastestLabel = ""
        streakCount = 0
        streakDay = ""
        hints = 3
        prefs = JGPrefs()
        active = nil
        dailyLog = []
    }

    enum CodingKeys: String, CodingKey {
        case records, piecesPlaced, puzzlesCompleted, fastestSeconds, fastestLabel
        case streakCount, streakDay, hints, prefs, active, dailyLog
    }

    init(from decoder: Decoder) throws {
        self.init()
        guard let box = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? box.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        records = value(.records, [String: JGRecord]())
        piecesPlaced = value(.piecesPlaced, 0)
        puzzlesCompleted = value(.puzzlesCompleted, 0)
        fastestSeconds = value(.fastestSeconds, 0)
        fastestLabel = value(.fastestLabel, "")
        streakCount = value(.streakCount, 0)
        streakDay = value(.streakDay, "")
        hints = value(.hints, 3)
        prefs = value(.prefs, JGPrefs())
        dailyLog = value(.dailyLog, [JGDailyEntry]())
        active = ((try? box.decodeIfPresent(JGActivePuzzle.self, forKey: .active)) ?? nil)
    }

    static func key(picture: String, tier: Int) -> String { "\(picture)#\(tier)" }

    func record(picture: String, tier: Int) -> JGRecord {
        records[JGArchive.key(picture: picture, tier: tier)] ?? JGRecord()
    }

    /// A picture earns its frame in the gallery as soon as any one of its cuts is finished.
    func isUnlocked(picture: String) -> Bool {
        for tier in JGTiers.all where record(picture: picture, tier: tier.id).completed {
            return true
        }
        return false
    }

    func completedTierCount(picture: String) -> Int {
        JGTiers.all.reduce(0) { $0 + (record(picture: picture, tier: $1.id).completed ? 1 : 0) }
    }
}
