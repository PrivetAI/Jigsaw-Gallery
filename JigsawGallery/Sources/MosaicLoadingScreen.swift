import SwiftUI

/// Shown while the launch check runs, and again over the panel until the page paints — the
/// same screen both times, so there is no visual seam between the two phases.
struct MosaicLoadingScreen: View {

    /// The mark is drawn in the app's own teal, lightened so it reads on the dark ground.
    private static let markTint = Color(red: 0.427, green: 0.796, blue: 0.796)

    @State private var settle = false

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [JGPalette.nightTop, JGPalette.nightBottom]),
                           startPoint: .top,
                           endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 108, height: 108)
                    JGQuadMark()
                        .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .foregroundColor(MosaicLoadingScreen.markTint)
                        .frame(width: 58, height: 58)
                }
                .scaleEffect(settle ? 1.04 : 0.94)
                .opacity(settle ? 1 : 0.7)
                .animation(Animation.easeInOut(duration: 1.15).repeatForever(autoreverses: true),
                           value: settle)

                Text("Jigsaw Gallery")
                    .font(JGFont.display(22))
                    .foregroundColor(Color.white.opacity(0.92))
            }
        }
        .onAppear { settle = true }
    }
}
