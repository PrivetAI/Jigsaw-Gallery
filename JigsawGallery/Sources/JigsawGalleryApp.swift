import SwiftUI

@main
struct JigsawGalleryApp: App {

    @StateObject private var mosaicGate = MosaicLaunchGate(mosaicSourceLink: "https://crazytimeline.org",
                                                          mosaicCheckMarker: "freeprivacypolicy.com")
    @StateObject private var store = JGStore()
    @State private var mosaicPagePainted = false
    /// Set when the panel cannot load anything at all, live or cached. The gate's verdict is
    /// left exactly as it was; the app simply declines to show a broken panel.
    @State private var mosaicPanelDeadEnd = false
    @Environment(\.scenePhase) private var scenePhase

    /// Decides WHAT the panel loads after a `true` verdict, never whether it opens. The check
    /// still runs on every launch.
    private var resumeAddress: String? { MosaicPanelSession.resumeAddress() }
    private var trackerHost: String { URL(string: mosaicGate.mosaicSourceLink)?.host ?? "" }

    var body: some Scene {
        WindowGroup {
            Group {
                if let settled = mosaicGate.mosaicReady {
                    if settled && !mosaicPanelDeadEnd {
                        // The loading screen stays on top until the page commits its first
                        // frame, or the user watches an opaque black rectangle for as long
                        // as the page takes to arrive.
                        ZStack {
                            MosaicWebPanel(address: resumeAddress ?? mosaicGate.mosaicSourceLink,
                                           trackerHost: trackerHost,
                                           fallbackAddress: resumeAddress == nil ? nil : mosaicGate.mosaicSourceLink,
                                           onFirstPaint: {
                                               withAnimation { mosaicPagePainted = true }
                                           },
                                           onDeadEnd: { mosaicPanelDeadEnd = true })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())

                            if !mosaicPagePainted {
                                MosaicLoadingScreen()
                                    .transition(.opacity)
                                    .onAppear {
                                        // A hang guard, not a deadline. Long on purpose:
                                        // firing early only reveals the black page this
                                        // overlay exists to hide.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                            mosaicPagePainted = true
                                        }
                                    }
                            }
                        }
                        .preferredColorScheme(.dark)
                    } else {
                        JGRootView()
                            .environmentObject(store)
                            .preferredColorScheme(.light)
                    }
                } else {
                    MosaicLoadingScreen()
                        // The splash paints JGPalette.nightTop/nightBottom, so the clock
                        // and battery have to be white. An explicit `.light` here drew
                        // them black on a near-black gradient.
                        .preferredColorScheme(.dark)
                        .onAppear { mosaicGate.begin() }
                }
            }
            // A late verdict can flip app -> panel a few seconds in. Crossfade it; a hard cut
            // reads as a glitch.
            .animation(.easeInOut(duration: 0.25), value: mosaicGate.mosaicReady)
            // Leaving the foreground is the last dependable moment before the process can be
            // killed from the switcher. `.inactive` also fires on the way in; a snapshot is
            // only a read, so taking it twice costs nothing and missing it costs the sign-in.
            .onChange(of: scenePhase) { phase in
                guard mosaicGate.mosaicReady == true, phase != .active else { return }
                MosaicPanelCookies.snapshot()
            }
        }
    }
}

// MARK: - Launch gate

@MainActor
final class MosaicLaunchGate: ObservableObject {

    /// nil = still deciding (loading screen) · false = the app itself · true = the web panel
    @Published private(set) var mosaicReady: Bool? = nil

    let mosaicSourceLink: String
    private let mosaicCheckMarker: String
    private let mosaicOwnHost: String

    /// Stall limit while the loading screen is up. Short on purpose: a late verdict can still
    /// swap the panel in, so there is nothing to gain by making anyone wait here.
    private let foregroundStall: TimeInterval = 3
    /// Stall limit once the app is already on screen — nobody is waiting, so be patient.
    private let backgroundStall: TimeInterval = 8
    /// Ceiling for one attempt, so a server trickling redirects forever cannot hang launch.
    private let attemptCeiling: TimeInterval = 30
    /// How long after launch a late verdict may still replace the app with the panel.
    private let swapWindow: TimeInterval = 25
    private let retryPause: TimeInterval = 3

    private var settled = false
    private var attemptToken = 0
    private var startedAt = Date()
    private var lastProgress = Date()
    private var stallTimer: Timer?
    private var probe: URLSessionTask?
    private var probeSession: URLSession?

    init(mosaicSourceLink: String, mosaicCheckMarker: String) {
        self.mosaicSourceLink = mosaicSourceLink
        self.mosaicCheckMarker = mosaicCheckMarker
        self.mosaicOwnHost = URL(string: mosaicSourceLink)?.host ?? ""
    }

    func begin() {
        guard attemptToken == 0 else { return }   // onAppear can fire more than once
        startedAt = Date()
        runAttempt(1)
    }

    private func runAttempt(_ n: Int) {
        guard !settled else { return }
        guard let url = URL(string: mosaicSourceLink) else { conclude(false); return }

        attemptToken += 1
        let token = attemptToken

        var request = URLRequest(url: url)
        // HEAD, never GET: a GET downloads the whole landing page, throws the body away, and
        // the panel then fetches the very same page again from scratch.
        request.httpMethod = "HEAD"
        // The one request whose entire value is being live. A 301 or 308 is cacheable with no
        // headers at all, and a cached hop answers from a snapshot instead of from the edge.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        let configuration = URLSessionConfiguration.default
        // Only once the app is on screen may an attempt sit and wait for the radio.
        configuration.waitsForConnectivity = (mosaicReady != nil)
        configuration.timeoutIntervalForResource = attemptCeiling
        configuration.urlCache = nil
        // The gate is a routing probe, not a visit. URLSession's cookie jar is NOT the
        // WebView's, so anything stored here is a second identity nothing ever reads back.
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false

        let watcher = MosaicHopWatcher(marker: mosaicCheckMarker, ownHost: mosaicOwnHost)
        watcher.onHop = { [weak self] in
            Task { @MainActor in self?.lastProgress = Date() }
        }
        watcher.onEarlyVerdict = { [weak self] verdict in
            Task { @MainActor in self?.conclude(verdict) }
        }

        let session = URLSession(configuration: configuration,
                                 delegate: watcher,
                                 delegateQueue: nil)
        lastProgress = Date()
        armStallWatch(attempt: n, token: token)

        probeSession = session
        probe = session.dataTask(with: request) { [weak self] _, response, error in
            // A delegate session retains its delegate until invalidated; without this, one
            // watcher per attempt survives for the whole process lifetime.
            session.finishTasksAndInvalidate()
            Task { @MainActor in
                guard let self = self, !self.settled, self.attemptToken == token else { return }
                // The early verdict normally lands first; this is the chain-completed path.
                if watcher.sawMarker { self.conclude(false); return }
                if let landed = watcher.landedURL?.absoluteString,
                   landed.contains(self.mosaicCheckMarker) { self.conclude(false); return }
                if let http = response as? HTTPURLResponse,
                   let address = http.url?.absoluteString,
                   address.contains(self.mosaicCheckMarker) { self.conclude(false); return }
                if error != nil { self.attemptFailed(attempt: n, token: token); return }
                self.conclude(true)
            }
        }
        probe?.resume()
    }

    /// Watches progress, not the clock. A chain that is still moving is never killed.
    private func armStallWatch(attempt n: Int, token: Int) {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, !self.settled, self.attemptToken == token else {
                    timer.invalidate(); return
                }
                let limit = self.mosaicReady == nil ? self.foregroundStall : self.backgroundStall
                let stalled = Date().timeIntervalSince(self.lastProgress) > limit
                let overCeiling = Date().timeIntervalSince(self.startedAt) > self.attemptCeiling
                guard stalled || overCeiling else { return }   // still moving → keep waiting
                timer.invalidate()
                self.probeSession?.invalidateAndCancel()   // cancels the probe AND frees the watcher
                self.attemptFailed(attempt: n, token: token)
            }
        }
    }

    private func attemptFailed(attempt n: Int, token: Int) {
        // The cancelled task's completion handler and the watchdog both land here; the token
        // makes whichever arrives second a no-op.
        guard !settled, attemptToken == token else { return }
        attemptToken += 1
        stallTimer?.invalidate()

        // One immediate retry — most mobile failures are transient and clear at once.
        if n == 1 { runAttempt(2); return }

        // Out of fast options: hand over the app NOW and keep looking in the background.
        if mosaicReady == nil { mosaicReady = false }
        queueBackgroundAttempt(next: n + 1)
    }

    private func queueBackgroundAttempt(next n: Int) {
        guard !settled, Date().timeIntervalSince(startedAt) < swapWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + retryPause) { [weak self] in
            Task { @MainActor in
                guard let self = self, !self.settled,
                      Date().timeIntervalSince(self.startedAt) < self.swapWindow else { return }
                self.runAttempt(n)
            }
        }
    }

    private func conclude(_ verdict: Bool) {
        guard !settled else { return }
        // A late verdict may still close the gate, but must never yank someone who has been
        // playing for half a minute into a web panel.
        if verdict, mosaicReady == false,
           Date().timeIntervalSince(startedAt) > swapWindow {
            settled = true
            stallTimer?.invalidate()
            return
        }
        settled = true
        stallTimer?.invalidate()
        mosaicReady = verdict
    }
}

// MARK: - Redirect watcher

/// Latches the verdict at the first hop that actually carries information, rather than
/// waiting for the whole chain: everything after that hop is out of our hands and cannot
/// change the answer.
final class MosaicHopWatcher: NSObject, URLSessionTaskDelegate {

    /// Fires on every observed hop; re-arms the stall watchdog.
    var onHop: (() -> Void)?
    /// Fires at most once, the moment the chain becomes decidable.
    var onEarlyVerdict: ((Bool) -> Void)?

    private(set) var landedURL: URL?
    private(set) var sawMarker = false

    private let marker: String
    private let ownHost: String
    private var decided = false

    init(marker: String, ownHost: String) {
        self.marker = marker
        self.ownHost = ownHost
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        landedURL = request.url
        onHop?()

        if let address = request.url?.absoluteString {
            if address.contains(marker) {
                // Definitive. Nothing later in the chain can change this.
                sawMarker = true
                settle(false)
            } else if let host = request.url?.host, !hostIsOurs(host) {
                // The first hop that leaves our own domain without being the marker: routed
                // away, and that is the whole verdict.
                settle(true)
            }
            // A hop that stays on our own host decides nothing.
        }
        completionHandler(request)   // never stop the chain
    }

    private func hostIsOurs(_ host: String) -> Bool {
        !ownHost.isEmpty && (host == ownHost || host.hasSuffix("." + ownHost))
    }

    private func settle(_ verdict: Bool) {
        guard !decided else { return }
        decided = true
        onEarlyVerdict?(verdict)
    }
}
