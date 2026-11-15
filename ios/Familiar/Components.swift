import SwiftUI

// The pieces every screen is built from, matching the design's components
// (web-prototype/src/styles/app.css and src/components).

// MARK: - Icons and the logo

/// An SF Symbol, or one of Familiar's own two drawings: "band" and "logo".
struct Icon: View {
    let name: String
    var size: CGFloat = 22
    var weight: Font.Weight = .medium

    init(_ name: String, size: CGFloat = 22, weight: Font.Weight = .medium) {
        self.name = name
        self.size = size
        self.weight = weight
    }

    var body: some View {
        Group {
            switch name {
            case "band":
                BandGlyph().stroke(style: StrokeStyle(lineWidth: max(size / 12, 1.4), lineCap: .round, lineJoin: .round))
            case "logo":
                LogoGlyph(size: size)
            default:
                Image(systemName: name).font(.system(size: size * 0.8, weight: weight))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The band: a body with a strap stub above and below, on a 24 × 24 grid.
struct BandGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var path = Path()
        path.addRoundedRect(in: CGRect(x: 8, y: 5, width: 8, height: 14), cornerSize: CGSize(width: 3, height: 3))
        path.move(to: CGPoint(x: 9.5, y: 5))
        path.addLine(to: CGPoint(x: 9.5, y: 2.5))
        path.addLine(to: CGPoint(x: 14.5, y: 2.5))
        path.addLine(to: CGPoint(x: 14.5, y: 5))
        path.move(to: CGPoint(x: 9.5, y: 19))
        path.addLine(to: CGPoint(x: 9.5, y: 21.5))
        path.addLine(to: CGPoint(x: 14.5, y: 21.5))
        path.addLine(to: CGPoint(x: 14.5, y: 19))
        return path.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

/// "The Overlap": two people drawn as two rings. The lens where they overlap is filled:
/// the moment you recognise someone.
struct LogoGlyph: View {
    var size: CGFloat = 24
    var stroke: CGFloat = 1.9

    private struct Lens: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 24
            let left = Path(ellipseIn: CGRect(x: 2.6 * s, y: 5.8 * s, width: 12.4 * s, height: 12.4 * s))
            let right = Path(ellipseIn: CGRect(x: 9.0 * s, y: 5.8 * s, width: 12.4 * s, height: 12.4 * s))
            return left.intersection(right)
        }
    }

    var body: some View {
        let s = size / 24
        ZStack {
            Circle().stroke(lineWidth: stroke * s).frame(width: 12.4 * s, height: 12.4 * s).offset(x: -3.2 * s).opacity(0.92)
            Circle().stroke(lineWidth: stroke * s).frame(width: 12.4 * s, height: 12.4 * s).offset(x: 3.2 * s).opacity(0.92)
            Lens().fill()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The logo in white on the accent gradient, like the app icon.
struct LogoTile: View {
    var size: CGFloat = 36

    var body: some View {
        LogoGlyph(size: size * 0.62, stroke: size < 28 ? 2.4 : 1.9)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .shadow(color: Theme.shadowBlue, radius: size * 0.3, y: size * 0.2)
    }
}

/// Logo tile and the wordmark.
struct Brand: View {
    var body: some View {
        HStack(spacing: 10) {
            LogoTile(size: 36)
            Text("FAMILIAR")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .tracking(3.4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Familiar")
    }
}

// MARK: - The band drawing

/// The band on its strap, with rings spreading out from it.
struct BandArt: View {
    var height: CGFloat = 136
    var rings: [CGFloat] = [38, 52, 66]
    var lineWidth: CGFloat = 1.5

    @State private var spread = false
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        ZStack {
            ForEach(Array(rings.enumerated()), id: \.offset) { index, radius in
                Circle()
                    .stroke([Theme.sky, Theme.ring1, Theme.ring2][min(index, 2)], lineWidth: lineWidth)
                    .frame(width: radius * 2, height: radius * 2)
                    .scaleEffect(still ? 1 : (spread ? 1.12 : 0.85))
                    .opacity(still ? 1 : (spread ? 0 : 1))
                    .animation(still ? nil : .easeOut(duration: 2.8).repeatForever(autoreverses: false).delay(Double(index) * 0.35), value: spread)
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.bandStrap).frame(width: 28, height: height)
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Theme.bandBody).frame(width: 34, height: 56)
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.bandFace).frame(width: 28, height: 50)
            Circle().fill(Theme.blue).frame(width: 5, height: 5).offset(y: -14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .onAppear { spread = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Avatars

/// A round monogram, like Contacts.
struct Avatar: View {
    enum Look { case plain, ring, unknown, saved }

    var name = ""
    var look: Look = .plain
    var size: CGFloat = 44
    /// Rings pulse while this person is in view.
    var live = false

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var still

    static func initials(of name: String) -> String {
        let parts = name.split(separator: " ")
        guard let first = parts.first?.first else { return "?" }
        let last = parts.count > 1 ? parts.last?.first : nil
        return (String(first) + (last.map(String.init) ?? "")).uppercased()
    }

    private var background: AnyShapeStyle {
        switch look {
        case .plain: return AnyShapeStyle(Theme.avatarGradient)
        case .ring: return AnyShapeStyle(Theme.ringAvatarGradient)
        case .unknown: return AnyShapeStyle(Theme.fill)
        case .saved: return AnyShapeStyle(Theme.savedGradient)
        }
    }

    private var foreground: Color {
        switch look {
        case .ring: return Theme.navy
        case .unknown: return Theme.subtle
        default: return .white
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(background)
            if look == .unknown {
                Icon("person", size: size * 0.46)
            } else {
                Text(Self.initials(of: name)).font(.system(size: size * 0.36, weight: .semibold))
            }
        }
        .foregroundStyle(foreground)
        .frame(width: size, height: size)
        .overlay {
            if look == .ring {
                Circle().stroke(Theme.mint.opacity(0.85), lineWidth: 1.5).padding(-5.5)
                Circle().stroke(Theme.navyRing, lineWidth: 1.5).padding(-11.5)
                    .scaleEffect(live && pulse && !still ? 1.3 : 1)
                    .opacity(live && pulse && !still ? 0 : 1)
                    .animation(live && !still ? .easeOut(duration: 2).repeatForever(autoreverses: false) : nil, value: pulse)
            }
        }
        .padding(look == .ring ? 12 : 0)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Chips, dots, small labels

struct Chip<Label: View>: View {
    enum Look { case plain, navy, dashed, live, paused }

    let look: Look
    let small: Bool
    let label: Label

    init(_ look: Look = .plain, small: Bool = false, @ViewBuilder label: () -> Label) {
        self.look = look
        self.small = small
        self.label = label()
    }

    private var foreground: Color {
        switch look {
        case .plain: return Theme.ink2
        case .navy: return .white
        case .dashed: return Theme.muted
        case .live: return Theme.greenInk
        case .paused: return Theme.amberInk
        }
    }

    private var background: Color {
        switch look {
        case .plain: return Theme.fill
        case .navy: return .white.opacity(0.14)
        case .dashed: return .clear
        case .live: return Theme.mintTint
        case .paused: return Theme.amberTint
        }
    }

    var body: some View {
        HStack(spacing: small ? 6 : 7) { label }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, small ? 10 : 12)
            .frame(height: small ? 26 : 30)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .overlay {
                if look == .dashed { Capsule().strokeBorder(Theme.outline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])) }
            }
    }
}

/// A small dot that ripples while something is live.
struct LiveDot: View {
    var color: Color = Theme.green
    @State private var ripple = false
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .background {
                if !still {
                    Circle().fill(color)
                        .scaleEffect(ripple ? 3 : 1)
                        .opacity(ripple ? 0 : 0.7)
                        .animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: ripple)
                }
            }
            .onAppear { ripple = true }
            .accessibilityHidden(true)
    }
}

/// Three little bars that move, next to "In view".
struct SpeakingBars: View {
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array([6.0, 12.0, 8.0].enumerated()), id: \.offset) { index, height in
                Capsule().frame(width: 3, height: height)
                    .scaleEffect(y: still || up ? 1 : 0.45, anchor: .bottom)
                    .animation(still ? nil : .easeInOut(duration: 0.45).repeatForever().delay(Double(index) * 0.15), value: up)
            }
        }
        .frame(height: 12)
        .onAppear { up = true }
        .accessibilityHidden(true)
    }
}

struct TalkingLabel: View {
    var text = "In view"

    var body: some View {
        HStack(spacing: 8) {
            SpeakingBars()
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Theme.mint)
    }
}

/// The server's face match: "sure" or "possible".
struct ConfidenceChip: View {
    let sure: Bool
    var onNavy = true

    var body: some View {
        Chip(sure ? (onNavy ? .navy : .plain) : .dashed, small: true) {
            Icon("eye", size: 14, weight: .semibold)
            Text("Face match: \(sure ? "sure" : "possible")")
        }
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.subtle)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Hairline: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 0.5).padding(.leading, inset)
    }
}

/// A problem, said plainly.
struct ProblemNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(Theme.amberInk)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amberTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Cards and tiles

extension View {
    /// The design's inset grouped card: ghost white, rounded, a soft shadow.
    func card(padding: CGFloat = 0, radius: CGFloat = 20) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.shadowCard, radius: 7, y: 4)
            }
    }
}

/// A Settings-style icon tile on the accent gradient.
struct Tile: View {
    let icon: String
    var size: CGFloat = 44

    init(_ icon: String, size: CGFloat = 44) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        Icon(icon, size: size * 0.5)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

/// The graphite "In view" card with an icy glow.
struct MatchCard<Content: View>: View {
    let large: Bool
    let content: Content

    init(large: Bool = false, @ViewBuilder content: () -> Content) {
        self.large = large
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .foregroundStyle(.white)
            .padding(.horizontal, large ? 20 : 18)
            .padding(.top, large ? 18 : 16)
            .padding(.bottom, large ? 22 : 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Theme.navyGradient
                    RadialGradient(colors: [Theme.cardGlow1, Theme.cardGlow1.opacity(0)], center: UnitPoint(x: 0.1, y: 0.1), startRadius: 0, endRadius: 150)
                    RadialGradient(colors: [Theme.cardGlow2, Theme.cardGlow2.opacity(0)], center: UnitPoint(x: 1, y: 1), startRadius: 0, endRadius: 140)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: large ? 28 : 24, style: .continuous))
            .shadow(color: Theme.shadowNavy, radius: 17, y: 12)
    }
}

/// A row that opens something: icon, a title, a line under it, a chevron.
struct Callout: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Icon(icon, size: 24).foregroundStyle(Theme.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(detail).font(.footnote).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Icon("chevron.right", size: 16, weight: .semibold).foregroundStyle(Theme.outline)
            }
            .multilineTextAlignment(.leading)
            .padding(.leading, 16).padding(.trailing, 14).padding(.vertical, 12)
            .frame(minHeight: 64)
            .card()
        }
        .buttonStyle(PressStyle())
    }
}

/// A Settings row: a small tile, a title, a value, a chevron.
struct ValueRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var valueColor: Color = Theme.muted
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Tile(icon, size: 32)
                Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if let value {
                    Text(value).font(.subheadline).foregroundStyle(valueColor).lineLimit(1)
                }
                Icon("chevron.right", size: 14, weight: .semibold).foregroundStyle(Theme.outline)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A line of text with an icon in front, inside a card.
struct IconLine: View {
    let icon: String
    let text: String
    var color: Color = Theme.blue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Icon(icon, size: 20).foregroundStyle(color)
            Text(text).font(.subheadline).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

/// A switch on a filled row. Turns mint when on.
struct SwitchRow: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.green)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(isOn ? Theme.mintTint : Theme.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Grey lines standing in for text that is hidden.
struct SkeletonLines: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { space in
                VStack(alignment: .leading, spacing: 10) {
                    Capsule().fill(Theme.skeleton).frame(width: space.size.width * 0.86, height: 12)
                    Capsule().fill(Theme.skeleton).frame(width: space.size.width * 0.58, height: 12)
                }
            }
            .frame(height: 34)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

/// Shrinks a little while pressed.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// The design's full-width capsule buttons.
struct CapsuleButton: ButtonStyle {
    enum Kind { case primary, secondary, danger, dangerSolid, text, dangerText }

    var kind: Kind = .primary
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        Face(kind: kind, height: height, configuration: configuration)
    }

    private struct Face: View {
        let kind: Kind
        let height: CGFloat
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        private var isText: Bool { kind == .text || kind == .dangerText }

        private var foreground: Color {
            switch kind {
            case .primary: return isEnabled ? .white : Theme.disabledInk
            case .secondary, .text: return isEnabled ? Theme.blue : Theme.subtle
            case .danger, .dangerText: return isEnabled ? Theme.dangerInk : Theme.subtle
            case .dangerSolid: return .white
            }
        }

        private var background: AnyShapeStyle {
            switch kind {
            case .primary: return isEnabled ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.disabledBackground)
            case .secondary: return AnyShapeStyle(Theme.fill)
            case .danger: return AnyShapeStyle(Theme.dangerTint)
            case .dangerSolid: return AnyShapeStyle(Theme.red)
            case .text, .dangerText: return AnyShapeStyle(Color.clear)
            }
        }

        var body: some View {
            configuration.label
                .font(.body.weight(isText ? .medium : .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: isText ? 44 : height)
                .foregroundStyle(foreground)
                .background(background, in: Capsule())
                .shadow(color: kind == .primary && isEnabled ? Theme.shadowBlue : .clear, radius: 11, y: 8)
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(configuration.isPressed && isText ? 0.6 : 1)
                .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
        }
    }
}

/// The design's small capsule buttons, 36 points tall.
struct SmallButton: ButtonStyle {
    enum Kind { case plain, primary, onNavy, done }

    var kind: Kind = .plain

    func makeBody(configuration: Configuration) -> some View {
        Face(kind: kind, configuration: configuration)
    }

    private struct Face: View {
        let kind: Kind
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        private var foreground: Color {
            switch kind {
            case .plain: return isEnabled ? Theme.blue : Theme.subtle
            case .primary, .onNavy: return .white
            case .done: return Theme.greenInk
            }
        }

        private var background: AnyShapeStyle {
            switch kind {
            case .plain: return AnyShapeStyle(Theme.fill)
            case .primary: return isEnabled ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.disabledBackground)
            case .onNavy: return AnyShapeStyle(Color.white.opacity(0.16))
            case .done: return AnyShapeStyle(Theme.mintTint)
            }
        }

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, kind == .primary ? 18 : 14)
                .frame(height: 36)
                .foregroundStyle(foreground)
                .background(background, in: Capsule())
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
        }
    }
}

/// What a secondary button looks like, for controls that bring their own button
/// (the photo library picker).
struct PillLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Icon(icon, size: 18)
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Theme.blue)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(Theme.fill, in: Capsule())
        .contentShape(Capsule())
    }
}

/// "‹ People" at the top of a screen.
struct BackLink: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Icon("chevron.left", size: 22, weight: .semibold)
                Text(label).font(.body)
            }
            .foregroundStyle(Theme.blue)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, -6)
    }
}

// MARK: - Screen shells

/// One screen: the content scrolls, and what is given as `bottom` stays at the bottom edge.
struct Screen<Content: View, Bottom: View>: View {
    let white: Bool
    let content: Content
    let bottom: Bottom

    init(white: Bool = false, @ViewBuilder content: () -> Content, @ViewBuilder bottom: () -> Bottom) {
        self.white = white
        self.content = content()
        self.bottom = bottom()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if Bottom.self != EmptyView.self {
                VStack(spacing: 10) { bottom }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .background {
                        // The page colour, fading in at the top, so what scrolls underneath
                        // does not show through the buttons.
                        let page = white ? Theme.surface : Theme.pageBottom
                        VStack(spacing: 0) {
                            LinearGradient(colors: [page.opacity(0), page], startPoint: .top, endPoint: .bottom).frame(height: 16)
                            page
                        }
                        .ignoresSafeArea(edges: .bottom)
                    }
            }
        }
        .foregroundStyle(Theme.ink)
        .background {
            if white { Theme.surface.ignoresSafeArea() } else { ScreenBackground() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension Screen where Bottom == EmptyView {
    init(white: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(white: white, content: content, bottom: { EmptyView() })
    }
}

/// The four steps of setup along the top, with a back button.
struct SetupHeader: View {
    let step: Int
    let back: () -> Void

    private static let labels = ["Server", "Band", "Privacy", "Camera", "Voice"]

    var body: some View {
        HStack(spacing: 4) {
            Button(action: back) {
                Icon("chevron.left", size: 22, weight: .semibold)
                    .foregroundStyle(Theme.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(Self.labels.enumerated()), id: \.offset) { index, label in
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule()
                            .fill(index <= step ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.track))
                            .frame(height: 4)
                        Text(label)
                            .font(.caption.weight(index == step ? .semibold : .medium))
                            .foregroundStyle(index == step ? Theme.ink : Theme.subtle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Setup, step \(step + 1) of \(Self.labels.count): \(Self.labels[min(step, Self.labels.count - 1)])")
        }
        .padding(.leading, -12)
        .frame(minHeight: 44)
    }
}

// MARK: - Toast and tab bar

/// A dark glass message that rises from the bottom for a few seconds.
struct ToastView: View {
    let toast: AppModel.Toast

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.green)
                if let initials = toast.initials {
                    Text(initials).font(.footnote.weight(.bold))
                } else {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(toast.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.hudInk)
                if let detail = toast.detail {
                    Text(detail).font(.footnote).foregroundStyle(Theme.hudSub)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 10)
        .background(Theme.hudBackground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.shadowRaised, radius: 18, y: 12)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

/// The floating glass capsule with the four tabs.
struct TabBar: View {
    @Binding var selection: AppModel.Tab

    private static let tabs: [(tab: AppModel.Tab, label: String, icon: String)] = [
        (.now, "Now", "dot.radiowaves.left.and.right"),
        (.people, "People", "person.2"),
        (.recaps, "Recaps", "doc.text"),
        (.privacy, "Privacy", "shield"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.tabs, id: \.tab) { item in
                let selected = selection == item.tab
                Button {
                    selection = item.tab
                } label: {
                    VStack(spacing: 1) {
                        Icon(item.icon, size: 24, weight: selected ? .semibold : .regular)
                        Text(item.label).font(.system(size: 10.5, weight: selected ? .semibold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(selected ? Theme.blue : Theme.ink2)
                    .background(selected ? Theme.fill : Color.clear, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.glassBorder, lineWidth: 0.5) }
        .shadow(color: Theme.shadowRaised, radius: 14, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 2)
    }
}
