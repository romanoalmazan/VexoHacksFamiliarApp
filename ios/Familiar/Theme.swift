import SwiftUI
import UIKit

// Familiar's colours and type, taken from the design (web-prototype/src/styles/tokens.css).
// Palette by name: ghost white, cool grey, freezing blue. Every colour has a light and a
// dark value, so the app follows the iPhone's appearance, or the one chosen in Settings.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// One colour for the light theme, another for the dark one.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }

    init(_ light: UInt32, _ dark: UInt32) {
        self.init(light: Color(hex: light), dark: Color(hex: dark))
    }

    init(_ light: UInt32, _ lightOpacity: Double, _ dark: UInt32, _ darkOpacity: Double) {
        self.init(light: Color(hex: light, opacity: lightOpacity), dark: Color(hex: dark, opacity: darkOpacity))
    }
}

enum Theme {
    // Ink: cool greys
    static let ink = Color(0x1E2330, 0xF8F8FF)
    static let ink2 = Color(0x2E3445, 0xE4E6EE)
    static let muted = Color(0x4C5468, 0xB4BACB)
    static let subtle = Color(0x737B92, 0x8C92AC)
    static let outline = Color(0x4C5468, 0.30, 0xF8F8FF, 0.26)

    // Surfaces: ghost white on cool grey
    static let surface = Color(0xF8F8FF, 0x242936)
    /// The page behind the screens, as it is near the bottom edge.
    static let pageBottom = Color(0xEAEDF3, 0x12141A)
    static let fill = Color(0x4C5468, 0.08, 0xF8F8FF, 0.08)
    static let fillStrong = Color(0x4C5468, 0.14, 0xF8F8FF, 0.14)
    static let tint = Color(0x2799E8, 0.10, 0x7AD6FF, 0.14)
    static let line = Color(0x4C5468, 0.14, 0xF8F8FF, 0.10)
    static let track = Color(0x4C5468, 0.14, 0xF8F8FF, 0.14)
    static let skeleton = Color(0x4C5468, 0.08, 0xF8F8FF, 0.08)
    static let glassBorder = Color(0xFFFFFF, 0.85, 0xF8F8FF, 0.10)
    static let hudBackground = Color(0x1E2330, 0.92, 0xF8F8FF, 0.94)
    static let hudInk = Color(0xF8F8FF, 0x1E2330)
    static let hudSub = Color(0xF8F8FF, 0.72, 0x1E2330, 0.68)
    static let disabledBackground = Color(0x8C92AC, 0.30, 0xF8F8FF, 0.12)
    static let disabledInk = Color(0xF8F8FF, 0.95, 0xF8F8FF, 0.45)

    // Accent: freezing blue. `blue` is for text and icons (5:1 on ghost white).
    static let accent = Color(0x2799E8, 0x3AAFF0)
    static let blue = Color(0x1673C2, 0x7AD6FF)
    static let blueSoft = Color(0x2799E8, 0.16, 0x7AD6FF, 0.18)

    // Status
    static let green = Color(0x2EA35A, 0x4CD27E)
    static let greenInk = Color(0x1E7A42, 0x74E39E)
    static let orange = Color(0xE58A00, 0xFFB04D)
    static let red = Color(0xE0364B, 0xFF6474)
    static let mintTint = Color(0x2EA35A, 0.13, 0x4CD27E, 0.16)
    static let amberTint = Color(0xE58A00, 0.14, 0xFFB04D, 0.16)
    static let amberInk = Color(0x8A5300, 0xFFC985)
    static let dangerInk = Color(0xBE2238, 0xFF8794)
    static let dangerTint = Color(0xE0364B, 0.09, 0xFF6474, 0.14)

    // The graphite "In view" card. It is dark in both themes.
    static let navy = Color(hex: 0x2A3040)
    static let mint = Color(hex: 0x8FDFFF)
    static let sky = Color(hex: 0x9EDCFF)
    static let skyText = Color(hex: 0xF8F8FF, opacity: 0.72)
    static let navyLine = Color(hex: 0xF8F8FF, opacity: 0.14)
    static let navyRing = Color(hex: 0xF8F8FF, opacity: 0.22)
    static let cardGlow1 = Color(0x63CBFF, 0.40, 0x63CBFF, 0.34)
    static let cardGlow2 = Color(0x9EDCFF, 0.22, 0x9EDCFF, 0.16)
    static let ring1 = Color(0x2799E8, 0.28, 0x7AD6FF, 0.30)
    static let ring2 = Color(0x4C5468, 0.10, 0xF8F8FF, 0.10)

    // The band drawing
    static let bandStrap = Color(0x3A4050, 0x232836)
    static let bandBody = Color(0x5E667C, 0x464E63)
    static let bandFace = Color(0x4C5468, 0x373E50)

    // Shadows
    static let shadowCard = Color(0x1E2330, 0.07, 0x000000, 0.26)
    static let shadowRaised = Color(0x1E2330, 0.12, 0x000000, 0.34)
    static let shadowNavy = Color(0x1E2330, 0.30, 0x000000, 0.42)
    static let shadowBlue = Color(0x2799E8, 0.30, 0x3AAFF0, 0.32)

    static let accentGradient = LinearGradient(
        stops: [.init(color: Color(0x63CBFF, 0x7AD6FF), location: 0),
                .init(color: Color(0x2799E8, 0x3AAFF0), location: 0.55),
                .init(color: Color(0x1673C2, 0x1E86D6), location: 1)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let navyGradient = LinearGradient(
        stops: [.init(color: Color(0x464E63, 0x3A4256), location: 0),
                .init(color: Color(0x2C3242, 0x2A3041), location: 0.5),
                .init(color: Color(0x1A1E29, 0x1D212D), location: 1)],
        startPoint: UnitPoint(x: 0.2, y: 0), endPoint: UnitPoint(x: 0.8, y: 1))

    static let avatarGradient = LinearGradient(
        colors: [Color(0xA6ADC2, 0x5E667C), Color(0x7C849C, 0x444B5E)], startPoint: .top, endPoint: .bottom)

    static let savedGradient = LinearGradient(
        colors: [Color(hex: 0x5BD27A), Color(hex: 0x30B455)], startPoint: .top, endPoint: .bottom)

    static let ringAvatarGradient = LinearGradient(
        colors: [Color(hex: 0xE9EEF7), Color(hex: 0xC9D2E1)], startPoint: .top, endPoint: .bottom)
}

/// The page behind every screen: cool grey with an icy glow in the top corners.
struct ScreenBackground: View {
    var body: some View {
        GeometryReader { space in
            ZStack {
                LinearGradient(colors: [Color(0xF4F5FA, 0x1B1F28), Color(0xE9ECF2, 0x111319)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(0x9EDCFF, 0.30, 0x3AAFF0, 0.12), Color(0x9EDCFF, 0, 0x3AAFF0, 0)],
                               center: .topLeading, startRadius: 0, endRadius: space.size.width * 0.8)
                RadialGradient(colors: [Color(0xA6ADC2, 0.22, 0x8C92AC, 0.10), Color(0xA6ADC2, 0, 0x8C92AC, 0)],
                               center: UnitPoint(x: 1, y: 0.04), startRadius: 0, endRadius: space.size.width * 0.6)
            }
        }
        .ignoresSafeArea()
    }
}
