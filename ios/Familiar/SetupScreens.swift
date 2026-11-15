import SwiftUI
import VexoBand

// Welcome and the five set-up-once screens: server, band, privacy, camera, voice.
// Each of the four device screens is also opened from Settings and from the Now tab;
// `next` is set only inside setup.

// MARK: - 01 · Welcome

struct WelcomeScreen: View {
    let start: () -> Void

    var body: some View {
        Screen {
            Brand().padding(.top, 20)
            Text("Know who’s with you, and what you last talked about.")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 32)
            Text("Your glasses see who you’re looking at. Your band hears the conversation. Familiar tells you who it is.")
                .font(.body).foregroundStyle(Theme.muted)
                .padding(.top, 12)

            BandArt().padding(.top, 20)

            MatchCard {
                HStack {
                    TalkingLabel(text: "In view · just now")
                    Spacer()
                    Chip(.navy, small: true) { Text("Example") }
                }
                HStack(spacing: 4) {
                    Avatar(name: "Maria", look: .ring)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This is Maria").font(.title3.weight(.bold))
                        Text("Your daughter").font(.subheadline).foregroundStyle(Theme.skyText)
                    }
                }
                .padding(.top, 6)
                Rectangle().fill(Theme.navyLine).frame(height: 0.5).padding(.top, 8)
                Text("Last time").font(.footnote.weight(.medium)).foregroundStyle(Theme.skyText).padding(.top, 14)
                Text("She told you about Leo’s graduation.").font(.body.weight(.semibold)).padding(.top, 4)
            }
            .padding(.top, 16)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Example of what you see and hear: This is Maria, your daughter. Last time, she told you about Leo’s graduation.")
        } bottom: {
            Button("Get started", action: start).buttonStyle(CapsuleButton())
            Text("Only people who agreed are recognised. Nothing is recorded until you tap Listen.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - 01b · Connect to your server

/// The server shows an address and a 6-digit pairing code. There are no accounts, and
/// every service key stays on the server.
struct ConnectScreen: View {
    let model: AppModel
    var next: (() -> Void)? = nil
    var backLabel: String? = "Settings"

    @AppStorage("serverAddress") private var serverAddress = ""
    @AppStorage("pairingCode") private var pairingCode = ""
    @FocusState private var typingCode: Bool

    private var faces: FaceClient { model.faces }
    /// Listening or looking: the connection is in use and cannot be changed now.
    private var inUse: Bool { model.isListening || model.watch.isOn }
    private var addressOK: Bool { TranscriptClient.url(from: serverAddress) != nil }
    private var canConnect: Bool { addressOK && pairingCode.count == 6 && !inUse }
    private var connected: Bool { faces.state == .live }

    var body: some View {
        Screen {
            StepHeader(step: 0, inSetup: next != nil, backLabel: backLabel)

            Group {
                if connected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Theme.green, in: Circle())
                        .transition(.scale.combined(with: .opacity))
                } else {
                    LogoTile(size: 64)
                }
            }
            .padding(.top, 20)
            .accessibilityHidden(true)

            Text(connected ? "Connected" : "Connect to your server")
                .font(.title.weight(.bold))
                .padding(.top, 20)
            Text(connected
                 ? "Your iPhone and the server can talk."
                 : "Start Familiar’s server on a laptop on this Wi-Fi. It shows an address and a 6-digit pairing code.")
                .font(.body).foregroundStyle(Theme.muted)
                .padding(.top, 6)

            HStack(spacing: 10) {
                Icon("dot.radiowaves.left.and.right", size: 20).foregroundStyle(Theme.subtle)
                TextField("ws://my-laptop.local:8765", text: $serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.next)
                    .onSubmit { typingCode = true }
                    .accessibilityLabel("Server address")
                if addressOK {
                    Image(systemName: "checkmark.circle").foregroundStyle(Theme.green)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .card()
            .padding(.top, 20)
            .disabled(inUse)

            SectionTitle("Pairing code").padding(.top, 18)
            codeBoxes.padding(.top, 8)

            Text(statusLine)
                .font(.footnote)
                .foregroundStyle(statusIsProblem ? Theme.dangerInk : Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10).padding(.leading, 4)

            HStack(alignment: .top, spacing: 8) {
                Icon("lock", size: 16)
                Text("Speech and face services are reached by the server. Their keys stay there, never in this app.")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.muted)
            .padding(.top, 24)
        } bottom: {
            if let next {
                Button(connected ? "Continue" : "Connect") {
                    if connected { next() } else { connect() }
                }
                .buttonStyle(CapsuleButton())
                .disabled(!connected && !canConnect)
                if !connected {
                    Button("Skip for now") { next() }.buttonStyle(CapsuleButton(kind: .text))
                }
            } else if !connected {
                Button("Connect") { connect() }
                    .buttonStyle(CapsuleButton())
                    .disabled(!canConnect)
            }
        }
        .animation(.spring(duration: 0.4), value: connected)
        .onAppear { model.editingServer = true }
        .onDisappear { model.editingServer = false }
        .onChange(of: serverAddress) { _, _ in edited() }
        .onChange(of: pairingCode) { _, typed in
            let digits = String(typed.filter(\.isNumber).prefix(6))
            guard digits == typed else {
                pairingCode = digits
                return
            }
            edited()
            if digits.count == 6 {
                typingCode = false
                if canConnect { connect() }
            }
        }
    }

    private var codeBoxes: some View {
        let digits = Array(pairingCode)
        return ZStack {
            TextField("", text: $pairingCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($typingCode)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .disabled(inUse)
                .accessibilityLabel("Pairing code")
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    let active = typingCode && index == min(digits.count, 5) && digits.count < 6
                    Text(index < digits.count ? String(digits[index]) : "")
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(connected ? Theme.greenInk : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surface)
                                .shadow(color: Theme.shadowCard, radius: 7, y: 4)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(connected ? Theme.green : active ? Theme.accent : Color.clear, lineWidth: 2)
                        }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if !inUse { typingCode = true } }
            .accessibilityHidden(true)
        }
    }

    private var statusIsProblem: Bool {
        if inUse { return false }
        if case .failed = faces.state { return true }
        return !serverAddress.isEmpty && !addressOK
    }

    private var statusLine: String {
        if inUse { return "Switch Listen off to change the server." }
        switch faces.state {
        case .connecting: return "Checking the code…"
        case .live: return "The address and the code are right."
        case .failed(let reason): return reason
        case .idle:
            if !serverAddress.isEmpty && !addressOK {
                return "That address does not look right. Copy it from the server’s window, for example ws://my-laptop.local:8765"
            }
            return "Both are in the server’s window on the laptop."
        }
    }

    /// The address or the code changed: what was connected is no longer what is typed.
    private func edited() {
        guard !inUse else { return }
        if faces.state == .live || faces.state == .connecting { faces.stop() }
    }

    private func connect() {
        guard canConnect else { return }
        faces.start(server: serverAddress, code: pairingCode)
    }
}

// MARK: - 02 · Pair band

/// Connects to the team's band, and to no other. Or to a pretend band, for trying
/// Familiar without the hardware.
struct PairScreen: View {
    let model: AppModel
    var next: (() -> Void)? = nil
    var backLabel: String? = "Settings"

    #if targetEnvironment(simulator)
    @State private var pretend = true           // the Simulator has no Bluetooth
    #else
    @State private var pretend = false
    #endif
    @State private var blinking = false

    private var band: BandClient { model.band }
    private var isLive: Bool { band.phase == .connected }

    private var isBusy: Bool {
        switch band.phase {
        case .searching, .connecting, .verifying, .reconnecting: return true
        default: return false
        }
    }

    /// Whether the row shows the pretend band: the one connected, or the one chosen.
    private var showsPretend: Bool { isLive || isBusy ? band.isPretend : pretend }

    var body: some View {
        Screen {
            StepHeader(step: 1, inSetup: next != nil, backLabel: backLabel)
            Text("Pair your band").font(.title.weight(.bold)).padding(.top, 20)
            Text("The band is Familiar’s ears. Its microphone streams to this iPhone over Bluetooth.")
                .font(.body).foregroundStyle(Theme.muted)
                .padding(.top, 8)

            BandArt(height: 120, rings: [34, 46, 58], lineWidth: 2).padding(.top, 18)

            SectionTitle(showsPretend ? "Pretend band" : "Your band").padding(.top, 20)
            bandRow.padding(.top, 8)

            if case .failed(let reason) = band.phase {
                ProblemNote(reason).padding(.top, 10)
            }

            if !isLive && !isBusy {
                SwitchRow(title: "Use a pretend band", detail: "For trying Familiar without the hardware.", isOn: $pretend)
                    .padding(.top, 14)
            }

            if !isLive {
                HStack(alignment: .top, spacing: 8) {
                    Icon("info.circle", size: 16)
                    Text(pretend
                         ? "A pretend band needs no hardware. It taps itself every 4 seconds and its sound is made up."
                         : "Double-tap the band first. Its light blinks blue for 60 seconds: that is when it can be found. Close the dashboard and any other program connected to it.")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.muted)
                .padding(.top, 14)
            }

            if isLive || band.phase == .reconnecting {
                SectionTitle("Band").padding(.top, 22)
                VStack(spacing: 0) {
                    DetailRow(label: "Name", value: band.bandName + (band.isPretend ? " (pretend)" : ""))
                    if let info = band.info {
                        Hairline(inset: 16)
                        DetailRow(label: "Firmware", value: info.firmware)
                    }
                    Hairline(inset: 16)
                    DetailRow(label: "Battery", value: batteryText)
                    Hairline(inset: 16)
                    DetailRow(label: "Signal", value: band.rssi.map { "\($0) dBm" } ?? "—")
                }
                .card()
                .padding(.top, 8)

                Button("Disconnect") {
                    if model.isListening { model.listen(false) }
                    band.disconnect()
                }
                .buttonStyle(CapsuleButton(kind: .danger, height: 48))
                .padding(.top, 12)
            }

            if !band.log.isEmpty {
                SectionTitle("Activity").padding(.top, 22)
                VStack(spacing: 0) {
                    ForEach(Array(band.log.prefix(12).enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Hairline(inset: 16) }
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text(entry.time, format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.subtle)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                }
                .card()
                .padding(.top, 8)
            }
        } bottom: {
            if let next {
                Button("Continue") { next() }
                    .buttonStyle(CapsuleButton())
                    .disabled(!isLive)
                if !isLive {
                    Button("Skip for now") { next() }.buttonStyle(CapsuleButton(kind: .text))
                }
            }
        }
        .animation(.default, value: band.phase)
    }

    private var bandRow: some View {
        HStack(spacing: 12) {
            Tile("band")
            VStack(alignment: .leading, spacing: 2) {
                Text(showsPretend ? "Pretend band" : "Band \(band.band)").font(.body.weight(.semibold))
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(isLive ? Theme.greenInk : Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if isBusy {
                ProgressView()
                Button("Cancel") { band.disconnect() }.buttonStyle(SmallButton())
            } else if isLive {
                Button(blinking ? "Blinking…" : "Blink") {
                    blinking = true
                    Task {
                        await band.identify()
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        blinking = false
                    }
                }
                .buttonStyle(SmallButton())
                .disabled(band.micOn || blinking)
                .accessibilityLabel("Blink the band’s light")
            } else {
                Button("Connect") { band.connect(pretend: pretend) }
                    .buttonStyle(SmallButton(kind: .primary))
            }
        }
        .padding(12)
        .card()
    }

    private var statusText: String {
        switch band.phase {
        case .idle: return pretend ? "Plays made-up sound" : "Your team’s band"
        case .searching: return "Looking for \(band.bandName)…"
        case .connecting: return "Found it. Connecting…"
        case .verifying: return "Checking it is your band…"
        case .connected: return band.micOn ? "Connected · microphone on" : "Connected"
        case .reconnecting: return "Link lost. Reconnecting…"
        case .failed: return "Not connected"
        }
    }

    private var batteryText: String {
        guard let battery = band.battery else { return "—" }
        let state = battery.state == 1 ? ", charging" : battery.state == 2 ? ", charged" : ""
        return "\(battery.percent)%\(state)"
    }
}

/// A label on the left, its value on the right.
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(Theme.muted).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 03 · How Familiar listens

struct SetupPrivacyScreen: View {
    let model: AppModel
    let next: () -> Void

    @State private var showingSomeone = false
    @Environment(\.dismiss) private var dismiss

    static let points: [(icon: String, title: String, body: String)] = [
        ("person.2", "Only people who agreed", "Someone is recognised only after they, or their family, agree and you register them."),
        ("eye", "Strangers stay hidden", "Words from anyone not registered are hidden, never saved, and dropped when the conversation ends."),
        ("clock", "Pictures are thrown away", "Camera pictures are compared and discarded. Only numbers describing each face are kept."),
        ("doc.text", "Text only, no audio", "Conversations are kept as text, on your server. No sound is stored."),
    ]

    var body: some View {
        Screen {
            SetupHeader(step: 2) { dismiss() }
            Text("How Familiar listens").font(.title.weight(.bold)).padding(.top, 20)
            Text("Read this with the people around you.")
                .font(.body).foregroundStyle(Theme.muted)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(Self.points.enumerated()), id: \.offset) { index, point in
                    if index > 0 { Hairline(inset: 60) }
                    HStack(alignment: .top, spacing: 12) {
                        Tile(point.icon, size: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(point.title).font(.callout.weight(.semibold))
                            Text(point.body).font(.subheadline).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                }
            }
            .card()
            .padding(.top, 18)

            HStack(alignment: .top, spacing: 12) {
                Icon("info.circle", size: 20).foregroundStyle(Theme.amberInk)
                Text("While Listen is on, the speech service hears the whole room to make the text. Tell people near you.")
                    .font(.subheadline).foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.amberTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 12)

            Callout(icon: "person.2", title: "Show someone what Familiar does", detail: "Hand your phone to the other person.") {
                showingSomeone = true
            }
            .padding(.top, 12)
        } bottom: {
            Button("I understand", action: next).buttonStyle(CapsuleButton())
        }
        .sheet(isPresented: $showingSomeone) { ShowSomeoneScreen(model: model) }
    }
}

// MARK: - 04 · Choose a camera

/// The Meta glasses (through Meta's Wearables Device Access Toolkit) or the iPhone's camera.
struct CameraScreen: View {
    let model: AppModel
    var next: (() -> Void)? = nil
    var backLabel: String? = "Settings"

    @AppStorage("useGlasses") private var useGlasses = false

    private var glasses: GlassesCamera { model.glasses }
    private var linked: Bool { glasses.isLinked || glasses.isPretend }
    /// The camera is on: it cannot be swapped now.
    private var inUse: Bool { model.watch.isOn }

    var body: some View {
        Screen {
            StepHeader(step: 3, inSetup: next != nil, backLabel: backLabel)
            Text("Choose a camera").font(.title.weight(.bold)).padding(.top, 20)
            Text("The camera is Familiar’s eyes. About one picture a second goes to your server, is compared and thrown away.")
                .font(.body).foregroundStyle(Theme.muted)
                .padding(.top, 8)

            VStack(spacing: 10) {
                choice(glasses: true, title: "Meta glasses", detail: "Sees who you’re looking at, hands-free.", icon: "eyeglasses")
                choice(glasses: false, title: "iPhone camera", detail: "Hold up your phone, or prop it on a table.", icon: "iphone")
            }
            .padding(.top, 20)
            .disabled(inUse)
            .opacity(inUse ? 0.6 : 1)

            if inUse {
                Text("Switch Listen off to change the camera.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                    .padding(.top, 8).padding(.leading, 4)
            }

            if useGlasses {
                VStack(alignment: .leading, spacing: 0) {
                    Text(linked ? "Glasses linked" : "Link your glasses").font(.body.weight(.semibold))
                    Text(linked
                         ? "Meta AI approved Familiar. The first time you look for faces, it asks to allow the camera."
                         : "In Meta AI, turn on Developer Mode (Settings → Your glasses → Developer Mode). Then link: Meta AI opens, asks, and comes back here.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    if !linked {
                        Button(glasses.isLinking ? "Waiting for Meta AI…" : "Link Meta glasses") {
                            Task { await glasses.link() }
                        }
                        .buttonStyle(CapsuleButton(kind: .secondary, height: 48))
                        .disabled(glasses.isLinking)
                        .padding(.top, 12)
                    }
                    if case .problem(let reason) = glasses.status {
                        ProblemNote(reason).padding(.top, 12)
                    }
                }
                .card(padding: 16)
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SwitchRow(title: "Say who it is out loud", detail: "“This is Maria, your daughter.”",
                      isOn: Binding(get: { model.saysNames }, set: { model.saysNames = $0 }))
                .padding(.top, 14)
        } bottom: {
            if let next {
                Button(useGlasses && !linked ? "Link the glasses first" : "Continue") { next() }
                    .buttonStyle(CapsuleButton())
                    .disabled(useGlasses && !linked)
                if useGlasses && !linked {
                    Button("Skip for now") { next() }.buttonStyle(CapsuleButton(kind: .text))
                }
            }
        }
        .animation(.spring(duration: 0.35), value: useGlasses)
    }

    private func choice(glasses: Bool, title: String, detail: String, icon: String) -> some View {
        let on = useGlasses == glasses
        return Button {
            useGlasses = glasses
        } label: {
            HStack(spacing: 12) {
                Tile(icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(detail).font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                ZStack {
                    Circle().fill(on ? Theme.accent : Color.clear)
                    Circle().strokeBorder(on ? Theme.accent : Theme.outline, lineWidth: 1.5)
                    if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
                }
                .frame(width: 22, height: 22)
            }
            .padding(12)
            .card()
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(on ? Theme.accent : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

// MARK: - 04b · Register my voice

/// The wearer reads for 12 seconds through the band. The server keeps a description of
/// how their voice sounds, never sound. Then "You" is whoever sounds like the wearer.
struct VoiceScreen: View {
    let model: AppModel
    var next: (() -> Void)? = nil
    var backLabel: String? = "Settings"

    @AppStorage("serverAddress") private var serverAddress = ""
    @AppStorage("pairingCode") private var pairingCode = ""
    @AppStorage("voiceRegistered") private var voiceRegistered = false
    @Environment(\.dismiss) private var dismiss
    @State private var voice = VoiceRegistration()
    @State private var moving = false

    private static let wave: [CGFloat] = [6, 10, 16, 24, 18, 30, 38, 26, 14, 20, 34, 40, 28, 18, 12, 22, 32, 26, 16, 10, 18, 28, 36, 24, 14, 8, 12, 20, 14, 8, 6]

    private var band: BandClient { model.band }
    private var bandReady: Bool { band.phase == .connected && !band.micOn }
    private var registered: Bool { voice.isRegistered == true }

    private var secondsLeft: Int? {
        if case .reading(let left) = voice.state { return left }
        return nil
    }

    private var isBusy: Bool {
        secondsLeft != nil || voice.state == .working || voice.state == .connecting
    }

    private var blocked: String? {
        if band.phase != .connected { return "Connect the band first." }
        if band.micOn, voice.state == .ready { return "Switch Listen off first." }
        return nil
    }

    private var progress: Double {
        if let secondsLeft { return Double(VoiceRegistration.readingSeconds - secondsLeft + 1) / Double(VoiceRegistration.readingSeconds) }
        if voice.state == .working { return 1 }
        return registered ? 1 : 0
    }

    private var statusLine: String {
        if let secondsLeft { return "Keep reading for \(secondsLeft) more second\(secondsLeft == 1 ? "" : "s")…" }
        switch voice.state {
        case .working: return "Learning your voice…"
        case .connecting: return "Connecting…"
        case .failed(let reason): return reason
        default:
            if let notice = voice.notice { return notice }
            return registered
                ? "Your voice is registered."
                : "Wear the band as usual and read for \(VoiceRegistration.readingSeconds) seconds. Its light turns blue while it listens. Somewhere quiet works best."
        }
    }

    var body: some View {
        Screen {
            StepHeader(step: 4, inSetup: next != nil, backLabel: backLabel)
            Text("Register my voice").font(.title.weight(.bold)).padding(.top, 20)
            Text("For the person wearing the band. Familiar keeps a description of how your voice sounds, not a recording, so it knows which voice is yours.")
                .font(.body).foregroundStyle(Theme.muted)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Read this in your normal voice").font(.footnote.weight(.medium)).foregroundStyle(Theme.muted)
                    Spacer()
                    if secondsLeft != nil {
                        HStack(spacing: 6) {
                            LiveDot(color: Theme.blue)
                            Text("Listening").font(.footnote.weight(.semibold)).foregroundStyle(Theme.blue)
                        }
                    } else if registered && !isBusy {
                        Chip(.live, small: true) {
                            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                            Text("Registered")
                        }
                    }
                }
                Text("“When the sunlight strikes raindrops in the air, they act as a prism and form a rainbow. The rainbow is a division of white light into many beautiful colours. These take the shape of a long round arch, with its path high above, and its two ends apparently beyond the horizon.”")
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                HStack(alignment: .center, spacing: 0) {
                    ForEach(Array(Self.wave.enumerated()), id: \.offset) { index, height in
                        Capsule().fill(Theme.accent)
                            .frame(width: 3, height: height)
                            .scaleEffect(y: moving ? 0.4 : 1)
                            .animation(moving ? .easeInOut(duration: 0.55).repeatForever().delay(Double(index % 7) * 0.09) : .default, value: moving)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 44)
                .opacity(secondsLeft != nil ? 1 : 0.35)
                .padding(.top, 16)
                .accessibilityHidden(true)

                GeometryReader { space in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        Capsule().fill(Theme.accentGradient).frame(width: space.size.width * progress)
                    }
                }
                .frame(height: 6)
                .padding(.top, 14)
                .animation(.linear(duration: 1), value: progress)
                .accessibilityHidden(true)

                Text(statusLine)
                    .font(.footnote)
                    .foregroundStyle({ if case .failed = voice.state { return Theme.dangerInk }; return Theme.muted }())
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .card(padding: 18)
            .padding(.top, 20)

            if let blocked {
                Text(blocked).font(.footnote).foregroundStyle(Theme.dangerInk)
                    .padding(.top, 10).padding(.leading, 4)
            }
        } bottom: {
            if !isBusy {
                Button {
                    voice.read(with: band)
                } label: {
                    Label(registered ? "Read it again" : "Start, then read it out loud", systemImage: "mic.fill")
                }
                .buttonStyle(CapsuleButton(kind: registered ? .secondary : .primary))
                .disabled(voice.state != .ready || !bandReady)

                if registered {
                    Button(next != nil ? "Finish setup" : "Done") { leave() }.buttonStyle(CapsuleButton())
                    Button("Forget my voice") { voice.forget() }
                        .buttonStyle(CapsuleButton(kind: .dangerText))
                        .disabled(voice.state != .ready)
                } else if next != nil {
                    Button("Skip for now") { leave() }.buttonStyle(CapsuleButton(kind: .text))
                }
            }
            Text(registered
                 ? "In every conversation, the voice that sounds like yours is shown as “You”."
                 : "Without a registered voice, the first voice heard after Listen is taken to be yours.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .onAppear { voice.connect(server: serverAddress, code: pairingCode) }
        .onDisappear {
            if case .reading = voice.state {
                band.onAudio = nil
                Task { await band.setMic(false) }
            }
            voice.close()
        }
        .onChange(of: voice.isRegistered) { _, registered in
            if let registered { voiceRegistered = registered }
        }
        .onChange(of: secondsLeft != nil) { _, reading in moving = reading }
    }

    private func leave() {
        if let next { next() } else { dismiss() }
    }
}
