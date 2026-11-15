import SwiftUI
import VexoBand

// The Privacy tab, the screen handed to the other person, and Settings.

// MARK: - 13 · Show someone what Familiar does

/// The screen the wearer hands to the other person.
struct ShowSomeoneScreen: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss

    private static let promises: [(icon: String, text: String)] = [
        ("person.2", "It only recognises people who agreed to it."),
        ("eye.slash", "If you’re not registered, your words are hidden and not kept."),
        ("eye", "Camera pictures are compared, then thrown away."),
        ("trash", "Ask, and you’ll be forgotten: your face data and notes are deleted."),
    ]

    var body: some View {
        Screen(white: true) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold)).foregroundStyle(Theme.blue)
                    .frame(height: 44)
            }
            .padding(.top, 8)

            BandArt(height: 110, rings: [32, 44, 54]).padding(.top, 4)
            Text("Hi! Familiar helps me remember people.")
                .font(.system(.title, weight: .bold))
                .padding(.top, 18)
            Text("My memory isn’t what it was. Here’s how it works:")
                .font(.title3).foregroundStyle(Theme.muted)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(Self.promises.enumerated()), id: \.offset) { _, promise in
                    HStack(alignment: .top, spacing: 14) {
                        Tile(promise.icon, size: 36)
                        Text(promise.text).font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }
                }
            }
            .padding(.top, 18)
        } bottom: {
            Button("Got it") { dismiss() }.buttonStyle(CapsuleButton())
            Button("Please don’t register me") {
                model.show(.init(title: "Okay, they won’t be registered", detail: "Their words stay hidden and aren’t kept."))
                dismiss()
            }
            .buttonStyle(CapsuleButton(kind: .secondary))
        }
    }
}

// MARK: - 14 · Privacy tab

struct PrivacyTabScreen: View {
    let model: AppModel

    @AppStorage("serverAddress") private var serverAddress = ""
    @State private var confirming = false

    private var listening: Bool { model.isListening }
    private var looking: Bool { model.watch.isOn }

    private static let keeps: [(icon: String, text: String)] = [
        ("person.2", "Each registered person’s name, relationship and numbers describing their face. No photos."),
        ("mic", "If you registered it, a description of how your own voice sounds. Never a recording."),
        ("doc.text", "Conversations with registered people, as text. No audio."),
        ("eye.slash", "Nothing about people who aren’t registered."),
    ]

    var body: some View {
        Screen {
            TitleRow("Privacy", model: model)

            HStack(spacing: 14) {
                Circle()
                    .fill(listening || looking ? Theme.green : Theme.outline)
                    .frame(width: 10, height: 10)
                    .overlay { if listening || looking { Circle().stroke(Theme.mintTint, lineWidth: 4).padding(-4) } }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(listening ? "Listening" : looking ? "Looking for faces" : "Not listening").font(.body.weight(.semibold))
                    Text(listening ? (looking ? "The band and the camera are on" : "The band’s microphone is on")
                         : looking ? "The camera is on. The band’s microphone is off."
                         : "Nothing is recorded until you tap Listen")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                if listening || looking {
                    Button {
                        if listening {
                            model.listen(false)
                            if !serverAddress.isEmpty { model.tab = .recaps }
                        } else {
                            model.look(false)
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(SmallButton())
                }
            }
            .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 10)
            .card()
            .padding(.top, 16)

            Callout(icon: "person.2", title: "Show someone what Familiar does", detail: "Hand your phone to the other person.") {
                model.sheet = .showSomeone
            }
            .padding(.top, 10)

            SectionTitle("What your server keeps").padding(.top, 22)
            VStack(spacing: 0) {
                ForEach(Array(Self.keeps.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Hairline(inset: 48) }
                    IconLine(icon: item.icon, text: item.text)
                }
            }
            .card()
            .padding(.top, 8)
            Text("While listening, the speech service hears the whole room to make the text. Tell people near you.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8).padding(.leading, 4)

            SectionTitle("While it is on").padding(.top, 22)
            VStack(spacing: 0) {
                IconLine(icon: "band", text: "The band’s light is solid blue whenever its microphone is on.")
                Hairline(inset: 48)
                IconLine(icon: "eyeglasses", text: "The glasses’ own light is on whenever their camera is.")
                Hairline(inset: 48)
                IconLine(icon: "clock", text: "About one picture a second goes to your server on this Wi-Fi. It is compared, then thrown away.")
            }
            .card()
            .padding(.top, 8)

            if confirming {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Forget everyone?").font(.body.weight(.semibold))
                    Text("Deletes all \(model.faces.people.count) people’s face data and profiles on the server. It can’t be undone.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .padding(.top, 4)
                    HStack(spacing: 10) {
                        Button("Cancel") { confirming = false }.buttonStyle(CapsuleButton(kind: .secondary, height: 48))
                        Button("Forget all") {
                            model.forgetEveryone()
                            confirming = false
                        }
                        .buttonStyle(CapsuleButton(kind: .dangerSolid, height: 48))
                    }
                    .padding(.top, 14)
                }
                .card(padding: 16)
                .padding(.top, 14)
                .transition(.scale(scale: 0.97).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(duration: 0.35)) { confirming = true }
                } label: {
                    Label("Forget everyone…", systemImage: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(model.faces.people.isEmpty ? Theme.subtle : Theme.dangerInk)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .disabled(model.faces.people.isEmpty)
                .padding(.top, 10)
            }
        }
        .onAppear { model.reach() }
    }
}

// MARK: - 15 · Settings

struct SettingsScreen: View {
    let model: AppModel

    @AppStorage("serverAddress") private var serverAddress = ""
    @AppStorage("useGlasses") private var useGlasses = false
    @AppStorage("voiceRegistered") private var voiceRegistered = false
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("setupDone") private var setupDone = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var path: [AppModel.Device] = []

    private var band: BandClient { model.band }
    private var connected: Bool { model.faces.state == .live || model.transcript.state == .live }
    private var host: String { TranscriptClient.url(from: serverAddress).flatMap { url in url.host.map { $0 + (url.port.map { ":\($0)" } ?? "") } } ?? serverAddress }

    private static let appearances: [(id: String, label: String, kind: ThemePreview.Kind)] = [
        ("light", "Light", .light), ("dark", "Dark", .dark), ("system", "Automatic", .split),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Screen {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.blue)
                        .frame(height: 44)
                }
                .padding(.top, 8)
                Text("Settings").font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)

                Button {
                    path.append(.server)
                } label: {
                    HStack(spacing: 12) {
                        if connected {
                            LogoTile(size: 44)
                        } else {
                            Avatar(look: .unknown)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(serverAddress.isEmpty ? "Connect to a server" : "Your Familiar server")
                                .font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text(serverAddress.isEmpty ? "Address and pairing code from the server"
                                 : "\(connected ? "Connected" : "Not connected") · \(host)")
                                .font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Icon("chevron.right", size: 14, weight: .semibold).foregroundStyle(Theme.outline)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 76)
                    .card()
                }
                .buttonStyle(PressStyle())
                .padding(.top, 16)

                SectionTitle("Devices").padding(.top, 24)
                VStack(spacing: 0) {
                    ValueRow(icon: "band", title: "Band", value: bandValue) { path.append(.band) }
                    Hairline(inset: 58)
                    ValueRow(icon: useGlasses ? "eyeglasses" : "eye", title: "Camera", value: useGlasses ? "Meta glasses" : "iPhone") { path.append(.camera) }
                    Hairline(inset: 58)
                    ValueRow(icon: "mic", title: "My voice", value: voiceRegistered ? "Registered" : "Not registered") { path.append(.voice) }
                }
                .card()
                .padding(.top, 8)

                SectionTitle("Recognition").padding(.top, 24)
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(get: { model.saysNames }, set: { model.saysNames = $0 })) {
                        HStack(spacing: 12) {
                            Tile("speaker.wave.2", size: 32)
                            Text("Say who it is out loud").font(.body.weight(.medium))
                        }
                    }
                    .tint(Theme.green)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    Hairline(inset: 58)
                    ValueRow(icon: "person.2", title: "People & faces", value: "\(model.faces.people.count) registered") {
                        model.sheet = nil
                        model.tab = .people
                    }
                }
                .card()
                .padding(.top, 8)

                SectionTitle("Appearance").padding(.top, 24)
                HStack(alignment: .top, spacing: 8) {
                    ForEach(Self.appearances, id: \.id) { option in
                        let on = appearance == option.id
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { appearance = option.id }
                        } label: {
                            VStack(spacing: 8) {
                                ThemePreview(kind: option.kind)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(on ? Theme.accent : Color.clear, lineWidth: 2.5)
                                    }
                                    .offset(y: on ? -2 : 0)
                                Text(option.label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                                ZStack {
                                    Circle().fill(on ? Theme.accent : Color.clear)
                                    Circle().strokeBorder(on ? Theme.accent : Theme.outline, lineWidth: 1.5)
                                    if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                                }
                                .frame(width: 22, height: 22)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(option.label)
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 14)
                .card()
                .padding(.top, 8)
                Text(appearance == "system"
                     ? "Automatic follows your iPhone. It’s \(scheme == .dark ? "dark" : "light") right now."
                     : "Familiar always uses the \(appearance) theme.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                    .padding(.top, 8).padding(.leading, 4)

                Button {
                    model.sheet = nil
                    setupDone = false
                } label: {
                    Text("Go through setup again")
                        .font(.body.weight(.medium)).foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .card()
                }
                .buttonStyle(PressStyle())
                .padding(.top, 16)

                Text("Familiar \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · Only people who agreed are recognised")
                    .font(.footnote).foregroundStyle(Theme.subtle)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
            }
            .navigationDestination(for: AppModel.Device.self) { device in
                DeviceScreen(model: model, device: device, backLabel: "Settings")
            }
        }
        .onAppear {
            if model.demoScreen == "settings-band" { path = [.band] }
        }
    }

    private var bandValue: String {
        switch band.phase {
        case .connected: return band.isPretend ? "Pretend band" : "Band \(band.band)"
        case .idle, .failed: return "Not connected"
        default: return "Connecting…"
        }
    }
}

/// A tiny phone drawn in one theme, or half and half, for the Appearance picker.
struct ThemePreview: View {
    enum Kind { case light, dark, split }

    let kind: Kind

    private struct Mini: View {
        let dark: Bool

        var body: some View {
            let background = Color(hex: dark ? 0x15181F : 0xEEF0F5)
            let card = Color(hex: dark ? 0x242936 : 0xF8F8FF)
            let ink = Color(hex: dark ? 0xF8F8FF : 0x1E2330)
            let line = dark ? Color(hex: 0xF8F8FF, opacity: 0.16) : Color(hex: 0x4C5468, opacity: 0.16)
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(ink).frame(width: 30, height: 6).padding(.leading, 2).padding(.top, 16)
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x2C3242)).frame(height: 30)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: 0x8FDFFF)).frame(width: 10, height: 10)
                            Capsule().fill(Color(hex: 0xF8F8FF, opacity: 0.85)).frame(width: 28, height: 4)
                        }
                        .padding(.leading, 6)
                    }
                    .padding(.top, 8)
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(card).frame(height: 16)
                    .overlay(alignment: .leading) { Capsule().fill(line).frame(width: 26, height: 4).padding(.leading, 6) }
                    .padding(.top, 6)
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: 0x2799E8)).frame(height: 12).padding(.top, 4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(width: 72, height: 112)
            .background(background)
        }
    }

    var body: some View {
        ZStack {
            Mini(dark: kind == .dark)
            if kind == .split {
                Mini(dark: true).mask(alignment: .trailing) { Rectangle().frame(width: 36) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line, lineWidth: 1) }
        .shadow(color: Theme.shadowCard, radius: 7, y: 4)
        .accessibilityHidden(true)
    }
}
