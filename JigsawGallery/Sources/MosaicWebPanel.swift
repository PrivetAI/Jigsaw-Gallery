import SwiftUI
import WebKit

/// One panel covers both uses: the fullscreen launch branch and the Privacy Policy sheet in
/// Settings. The sheet passes none of the resume plumbing, so its defaults switch it off.
struct MosaicWebPanel: UIViewRepresentable {

    let address: String
    /// Our own host — the tracker hop, which must never be remembered as a resume point. The
    /// Settings sheet passes none, and the empty value also turns remembering off for it.
    var trackerHost: String = ""
    /// Where to go when `address` is a resumed page that has since died. nil when the panel
    /// already started at the tracker link, and for the Settings sheet.
    var fallbackAddress: String? = nil
    /// Fires once, as soon as the page starts rendering, so the caller can lift the loading
    /// overlay. The Settings sheet passes nothing.
    var onFirstPaint: (() -> Void)? = nil
    /// Fires when nothing loads at all, live or cached. The caller shows the app instead.
    var onDeadEnd: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        var onDeadEnd: (() -> Void)?
        var trackerHost = ""
        var fallbackAddress: String?
        /// What the panel was first asked to load — the cache candidate when it was a
        /// resumed address.
        var openingAddress = ""
        private var painted = false
        private var triedFallback = false
        private var triedCache = false
        private var addressWatch: NSKeyValueObservation?

        deinit { addressWatch?.invalidate() }

        /// A same-document navigation — an SPA tab via `pushState`, a `#hash` tab — fires no
        /// navigation delegate callback at all, so `didCommit` alone would freeze the resume
        /// address on the last full page load. `url` is KVO-compliant and moves for both.
        func watchAddress(of panel: WKWebView) {
            addressWatch?.invalidate()
            addressWatch = panel.observe(\.url, options: [.new]) { [weak self] observed, _ in
                guard let self = self else { return }
                MosaicPanelSession.remember(observed.url, trackerHost: self.trackerHost)
            }
        }

        // didCommit, not didFinish: on a heavy landing page didFinish arrives seconds after
        // the content is already on screen and usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            MosaicPanelSession.remember(webView.url, trackerHost: trackerHost)
            release()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            MosaicPanelSession.remember(webView.url, trackerHost: trackerHost)
            // A sign-in POST has landed by now, so the jar is at its most interesting.
            MosaicPanelCookies.snapshot()
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            // A cancelled load is what an ordinary redirect looks like from here.
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            // Recovery is only for a panel that never got off the ground. After the first
            // paint a failed navigation is ordinary and WebKit lets the user go back.
            guard !painted else { return }
            recover(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            release()
        }

        /// resumed live -> tracker live -> the same address from the disk cache -> hand back
        /// the app. Never leave anyone on WebKit's error page: it is fullscreen here, with no
        /// back button, no reload and nothing to act on.
        private func recover(_ panel: WKWebView) {
            if !triedFallback, let fallback = fallbackAddress, let url = URL(string: fallback) {
                triedFallback = true
                MosaicPanelSession.forget()      // stop resuming an address that is gone
                panel.load(URLRequest(url: url))
                return
            }
            // Only worth trying for a real page — the tracker link is a redirect with
            // nothing cached behind it.
            if !triedCache, fallbackAddress != nil, let url = URL(string: openingAddress) {
                triedCache = true
                panel.load(URLRequest(url: url,
                                      cachePolicy: .returnCacheDataDontLoad,
                                      timeoutInterval: 15))
                return
            }
            onDeadEnd?()
        }

        private func release() {
            guard !painted else { return }
            painted = true
            onFirstPaint?()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let settings = WKWebViewConfiguration()
        settings.allowsInlineMediaPlayback = true
        settings.mediaTypesRequiringUserActionForPlayback = []
        // Stated outright because the signed-in session depends on it: the DEFAULT store is
        // the persistent, on-disk one. Never .nonPersistent().
        settings.websiteDataStore = .default()

        let panel = WKWebView(frame: .zero, configuration: settings)
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
        context.coordinator.openingAddress = address
        panel.navigationDelegate = context.coordinator
        context.coordinator.watchAddress(of: panel)
        panel.allowsBackForwardNavigationGestures = true
        panel.scrollView.bounces = true
        // Required, not optional: the frame runs under the home indicator and this is what
        // insets scrollable content back out of it. Never .never.
        panel.scrollView.contentInsetAdjustmentBehavior = .always
        // Opaque, so the safe-area band never flashes white.
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.scrollView.backgroundColor = .black
        // The branch presenting this runs in the dark scheme so the status bar glyphs turn
        // white. Pin the page itself back to light so that trait never reaches the site as
        // prefers-color-scheme: dark.
        panel.overrideUserInterfaceStyle = .light

        // Cookies FIRST, then load. The other order signs the user out on every cold start,
        // and the loading screen is still up, so the wait costs nothing visible.
        let target = address
        MosaicPanelCookies.restore { [weak panel] in
            guard let panel = panel, let url = URL(string: target) else { return }
            panel.load(URLRequest(url: url))
        }
        return panel
    }

    /// Must never reload — that would restart the page on every SwiftUI re-render. Refreshing
    /// the callbacks is the only thing allowed in here.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
    }
}

// MARK: - Resume address

/// Remembers the last page the panel was really on, so a cold start resumes there instead of
/// re-running the redirect chain from the top. It decides WHAT loads, never WHETHER the panel
/// opens — the launch check still runs on every single launch.
enum MosaicPanelSession {
    private static let addressKey = "mosaic.panel.resume.address"
    private static let stampKey   = "mosaic.panel.resume.stamp"
    /// Past this a resumed address is likelier to be stale than useful.
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 30

    static func remember(_ url: URL?, trackerHost: String) {
        // No tracker host means this is the Settings sheet, and remembering is off for it.
        // Without this guard the next launch would resume the privacy page.
        guard !trackerHost.isEmpty else { return }
        guard let url = url, url.scheme == "https",
              let host = url.host, !host.isEmpty else { return }
        // Never store our own hop: resuming it re-runs the very chain this avoids.
        if host == trackerHost || host.hasSuffix("." + trackerHost) { return }
        UserDefaults.standard.set(url.absoluteString, forKey: addressKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: stampKey)
    }

    static func resumeAddress() -> String? {
        guard let address = UserDefaults.standard.string(forKey: addressKey),
              let url = URL(string: address), url.host != nil else { return nil }
        let stamp = UserDefaults.standard.double(forKey: stampKey)
        guard stamp > 0, Date().timeIntervalSince1970 - stamp < maxAge else { return nil }
        return address
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: addressKey)
        UserDefaults.standard.removeObject(forKey: stampKey)
    }
}

// MARK: - Cookie mirror

/// Mirrors the WebKit cookie jar out to `UserDefaults` and back. A cookie with no expiry — a
/// plain session cookie, which is what most sign-ins hand out — lives in WebKit's networking
/// process and is never written to disk, so it dies the moment the app is swiped away.
enum MosaicPanelCookies {
    private static let key = "mosaic.panel.cookies"
    /// Expiry given to a cookie that had none. Long enough to outlive ordinary use.
    private static let sessionLifetime: TimeInterval = 60 * 60 * 24 * 180
    /// WebKit has been seen to swallow a `setCookie` completion. Past this, load regardless.
    private static let restoreGrace: TimeInterval = 1.5

    static func snapshot() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let payload: [[String: String]] = cookies.map { cookie in
                let expiry = cookie.expiresDate ?? Date().addingTimeInterval(sessionLifetime)
                return [
                    "name": cookie.name,
                    "value": cookie.value,
                    "domain": cookie.domain,
                    "path": cookie.path.isEmpty ? "/" : cookie.path,
                    "secure": cookie.isSecure ? "1" : "0",
                    "expires": String(expiry.timeIntervalSince1970)
                ]
            }
            // Wholesale overwrite, so a sign-out that empties the jar empties the mirror too
            // and cannot resurrect a dead session on the next launch.
            UserDefaults.standard.set(payload, forKey: key)
        }
    }

    /// Re-injects the mirror and then calls back. The caller MUST wait for this before the
    /// first load: a request that goes out early is the one that arrives signed out.
    static func restore(completion: @escaping () -> Void) {
        guard let payload = UserDefaults.standard.array(forKey: key) as? [[String: String]],
              !payload.isEmpty else { completion(); return }

        let store = WKWebsiteDataStore.default().httpCookieStore
        let now = Date()
        var finished = false
        let finish = {
            guard !finished else { return }
            finished = true
            completion()
        }

        let group = DispatchGroup()
        var queued = 0
        for entry in payload {
            guard let name = entry["name"], let value = entry["value"],
                  let domain = entry["domain"], let path = entry["path"],
                  let raw = entry["expires"], let seconds = TimeInterval(raw) else { continue }
            let expiry = Date(timeIntervalSince1970: seconds)
            guard expiry > now else { continue }
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: name, .value: value, .domain: domain, .path: path, .expires: expiry
            ]
            if entry["secure"] == "1" { props[.secure] = "TRUE" }
            guard let cookie = HTTPCookie(properties: props) else { continue }
            queued += 1
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }

        guard queued > 0 else { finish(); return }
        group.notify(queue: .main) { finish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreGrace) { finish() }
    }
}
