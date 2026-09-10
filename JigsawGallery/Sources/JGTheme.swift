import SwiftUI

/// Every colour in the app is stated outright, so the interface looks the same whatever the
/// device theme is set to. Nothing here reads a dynamic system colour.
enum JGPalette {

    static let paper       = Color(red: 0.957, green: 0.941, blue: 0.914)
    static let card        = Color(red: 1.000, green: 0.996, blue: 0.988)
    static let cardEdge    = Color(red: 0.855, green: 0.831, blue: 0.788)
    static let ink         = Color(red: 0.137, green: 0.149, blue: 0.180)
    static let inkSoft     = Color(red: 0.416, green: 0.435, blue: 0.475)
    static let inkFaint    = Color(red: 0.635, green: 0.647, blue: 0.678)

    static let teal        = Color(red: 0.078, green: 0.439, blue: 0.482)
    static let tealDeep    = Color(red: 0.043, green: 0.298, blue: 0.337)
    static let tealWash    = Color(red: 0.882, green: 0.929, blue: 0.929)
    static let amber       = Color(red: 0.784, green: 0.525, blue: 0.165)
    static let amberWash   = Color(red: 0.976, green: 0.929, blue: 0.851)
    static let rose        = Color(red: 0.792, green: 0.376, blue: 0.365)
    static let sage        = Color(red: 0.400, green: 0.522, blue: 0.416)
    static let clay        = Color(red: 0.596, green: 0.435, blue: 0.325)
    static let slate       = Color(red: 0.361, green: 0.416, blue: 0.529)

    /// Empty board felt, plus the ruled cell grid drawn over it.
    static let felt        = Color(red: 0.839, green: 0.816, blue: 0.769)
    static let feltRule    = Color(red: 0.769, green: 0.741, blue: 0.686)
    static let feltEdge    = Color(red: 0.643, green: 0.612, blue: 0.557)

    /// Splash / launch chrome. Shared by the check phase and the panel overlay, so the two
    /// never show a seam.
    static let nightTop    = Color(red: 0.055, green: 0.078, blue: 0.129)
    static let nightBottom = Color(red: 0.098, green: 0.153, blue: 0.196)

    static let tray        = Color(red: 0.914, green: 0.898, blue: 0.867)
    static let trayEdge    = Color(red: 0.816, green: 0.792, blue: 0.749)
}

enum JGFont {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

/// Layout metrics that have to react to the width the app actually got — an iPad in
/// landscape, an iPhone SE, or an iPad slide-over are all real cases here.
struct JGMetrics {
    let width: CGFloat
    let height: CGFloat

    var isCompactHeight: Bool { height < 700 }
    var isWide: Bool { width >= 700 }

    /// Content is centred and capped so a full-width iPad never stretches a reading column.
    var contentWidth: CGFloat { min(width, 620) }
    var gutter: CGFloat { isWide ? 28 : 18 }
    var cardCorner: CGFloat { 18 }
    /// Room left under a scroll so the last row clears the tab bar.
    var scrollTail: CGFloat { 112 }
}

extension View {
    func jgCard(corner: CGFloat = 18) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(JGPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(JGPalette.cardEdge, lineWidth: 1)
            )
    }
}

/// Formats a duration as m:ss, or h:mm:ss once it runs long.
func jgTimeText(_ seconds: Double) -> String {
    let total = max(0, Int(seconds.rounded()))
    let s = total % 60
    let m = (total / 60) % 60
    let h = total / 3600
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}
