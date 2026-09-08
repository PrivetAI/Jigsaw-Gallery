import Foundation
import SwiftUI
import UIKit

/// Everything that outlives a single sitting. One JSON blob in `UserDefaults` — no network,
/// no account, nothing leaves the device.
final class JGStore: ObservableObject {

    @Published private(set) var archive: JGArchive

    private let storageKey = "jigsawgallery.archive.v1"
    private let hintCeiling = 24
    private let hintsPerFinish = 2

    init() {
        if let raw = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(JGArchive.self, from: raw) {
            archive = decoded
        } else {
            archive = JGArchive()
        }
    }

    // MARK: Writing

    private func persist() {
        if let raw = try? JSONEncoder().encode(archive) {
            UserDefaults.standard.set(raw, forKey: storageKey)
        }
    }

    /// Mutate and write in one step, so no caller can change state without saving it.
    func edit(_ change: (inout JGArchive) -> Void) {
        change(&archive)
        persist()
    }

    /// Called on the way to the background. Nothing here depends on `.inactive`, which fires
    /// on the way in as well and would otherwise stamp a half-finished state.
    func flush() { persist() }

    // MARK: Preferences

    func setRotationDefault(_ on: Bool) { edit { $0.prefs.rotationDefault = on } }
    func setGhostDefault(_ mode: Int) { edit { $0.prefs.ghostDefault = max(0, min(2, mode)) } }
    func setSnapSensitivity(_ level: Int) { edit { $0.prefs.snapSensitivity = max(0, min(2, level)) } }
    func setHaptics(_ on: Bool) { edit { $0.prefs.haptics = on } }

    func resetEverything() {
        archive = JGArchive()
        persist()
    }

    // MARK: The puzzle in progress

    func storeActive(_ puzzle: JGActivePuzzle?) {
        edit { $0.active = puzzle }
    }

    func clearActive() {
        edit { $0.active = nil }
    }

    /// Only a puzzle whose picture and cut still exist can be resumed.
    var resumable: JGActivePuzzle? {
        guard let active = archive.active,
              JGGalleryCatalog.picture(id: active.pictureID) != nil,
              JGTiers.all.contains(where: { $0.id == active.tier }),
              !active.seated.isEmpty || active.elapsed > 3 else { return nil }
        return active
    }

    // MARK: Finishing

    /// Records a completed board. Returns true when this run set a new best for that cut.
    @discardableResult
    func recordFinish(picture: JGPicture, tier: JGTier, seconds: Double,
                      piecesPlacedThisRun: Int, isDaily: Bool, dayKey: String) -> Bool {
        var isBest = false
        edit { store in
            let key = JGArchive.key(picture: picture.id, tier: tier.id)
            var record = store.records[key] ?? JGRecord()
            record.completions += 1
            record.completed = true
            if record.bestSeconds <= 0 || seconds < record.bestSeconds {
                record.bestSeconds = seconds
                isBest = true
            }
            store.records[key] = record

            store.puzzlesCompleted += 1
            store.piecesPlaced += max(0, piecesPlacedThisRun)
            store.hints = min(hintCeiling, store.hints + hintsPerFinish)

            if store.fastestSeconds <= 0 || seconds < store.fastestSeconds {
                store.fastestSeconds = seconds
                store.fastestLabel = "\(picture.title) · \(tier.pieceCount) pieces"
            }

            if isDaily && !dayKey.isEmpty {
                if let previous = JGDaily.previousKey(of: dayKey), store.streakDay == previous {
                    store.streakCount += 1
                } else if store.streakDay != dayKey {
                    store.streakCount = 1
                }
                store.streakDay = dayKey
                store.dailyLog.removeAll { $0.day == dayKey }
                store.dailyLog.insert(JGDailyEntry(day: dayKey, pictureID: picture.id,
                                                   tier: tier.id, completed: true,
                                                   seconds: seconds), at: 0)
                if store.dailyLog.count > 40 { store.dailyLog.removeLast(store.dailyLog.count - 40) }
            }
            store.active = nil
        }
        return isBest
    }

    /// Credits pieces seated in a run that was left unfinished.
    func creditLoosePieces(_ count: Int) {
        guard count > 0 else { return }
        edit { $0.piecesPlaced += count }
    }

    // MARK: Hints

    @discardableResult
    func spendHint() -> Bool {
        guard archive.hints > 0 else { return false }
        edit { $0.hints -= 1 }
        return true
    }

    // MARK: Derived reading

    /// The streak only counts if the last finished daily was today or yesterday.
    func currentStreak(today: String) -> Int {
        guard archive.streakCount > 0 else { return 0 }
        if archive.streakDay == today { return archive.streakCount }
        if let yesterday = JGDaily.previousKey(of: today), archive.streakDay == yesterday {
            return archive.streakCount
        }
        return 0
    }

    func dailySolved(day: String) -> JGDailyEntry? {
        archive.dailyLog.first(where: { $0.day == day && $0.completed })
    }

    /// Best time recorded at a cut across every picture, and which picture it was.
    func bestAtTier(_ tier: JGTier) -> (seconds: Double, picture: String)? {
        var best: (Double, String)? = nil
        for picture in JGGalleryCatalog.pictures {
            let record = archive.record(picture: picture.id, tier: tier.id)
            guard record.completed, record.bestSeconds > 0 else { continue }
            if best == nil || record.bestSeconds < best!.0 {
                best = (record.bestSeconds, picture.title)
            }
        }
        guard let found = best else { return nil }
        return (found.0, found.1)
    }

    /// How many of a collection's 20 configurations are finished.
    func collectionProgress(_ collection: JGCollection) -> (done: Int, total: Int) {
        var done = 0
        for picture in collection.pictures {
            done += archive.completedTierCount(picture: picture.id)
        }
        return (done, collection.pictures.count * JGTiers.all.count)
    }

    var unlockedPictureCount: Int {
        JGGalleryCatalog.pictures.reduce(0) { $0 + (archive.isUnlocked(picture: $1.id) ? 1 : 0) }
    }

    var finishedConfigurationCount: Int {
        JGGalleryCatalog.pictures.reduce(0) { $0 + archive.completedTierCount(picture: $1.id) }
    }
}

/// A thin wrapper so the haptics preference is honoured in one place.
enum JGFeedback {
    static func tap(_ enabled: Bool) {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    static func seat(_ enabled: Bool) {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    static func finish(_ enabled: Bool) {
        guard enabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
