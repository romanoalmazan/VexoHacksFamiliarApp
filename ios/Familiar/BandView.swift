import SwiftUI
import VexoBand

/// Connect to the team's band and see that it works: status, battery, signal, taps, and
/// a microphone test that counts the sound packets arriving on the phone.
struct BandView: View {
    let band: BandClient
    let transcript: TranscriptClient
    let watch: FaceWatch

    @AppStorage("serverAddress") private var serverAddress = ""
    @AppStorage("pairingCode") private var pairingCode = ""
    @AppStorage("useGlasses") private var useGlasses = false
    @State private var registering = false

    #if targetEnvironment(simulator)
    @State private var pretend = true           // the Simulator has no Bluetooth
    #else
    @State private var pretend = false
    #endif

    private var isBusy: Bool {
        switch band.phase {
        case .searching, .connecting, .verifying, .reconnecting: return true
        default: return false
        }
    }

    private var isLive: Bool { band.phase == .connected }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statusRow
                    connectButton
                    if !isLive && !isBusy {
                        Toggle("Use a pretend band", isOn: $pretend)
                    }
                } footer: {
                    if !isLive {
                        Text(pretend
                             ? "A pretend band needs no hardware. It taps itself every 4 seconds and its sound is made up."
                             : "Double-tap the band first. Its light blinks blue for 60 seconds: that is when it can be found. Close the dashboard and any other program connected to it.")
                    }
                }

                if isLive || band.phase == .reconnecting {
                    Section("Band") {
                        LabeledContent("Name", value: band.bandName + (band.isPretend ? " (pretend)" : ""))
                        if let info = band.info {
                            LabeledContent("Firmware", value: info.firmware)
                        }
                        LabeledContent("Battery", value: batteryText)
                        LabeledContent("Signal", value: band.rssi.map { "\($0) dBm" } ?? "—")
                        Button("Blink the band's light") { Task { await band.identify() } }
                            .disabled(!isLive || band.micOn)
                    }

                    Section {
                        TextField("Server, e.g. ws://my-laptop.local:8765", text: $serverAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .disabled(band.micOn)
                        TextField("Pairing code", text: $pairingCode)
                            .keyboardType(.numberPad)
                            .disabled(band.micOn)
                        Toggle("Listen", isOn: Binding(
                            get: { band.micOn },
                            set: { on in listen(on) }
                        ))
                        .disabled(!isLive)
                        if band.micOn {
                            LabeledContent("Server", value: serverText)
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                LabeledContent("Sound arriving", value: audioText)
                            }
                            LabeledContent("Packets lost", value: "\(band.audioLost)")
                            LabeledContent(useGlasses ? "Glasses see" : "iPhone camera sees", value: inViewText)
                        }
                        if case .failed(let reason) = transcript.state {
                            Label(reason, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Live transcript")
                    } footer: {
                        Text(band.micOn
                             ? "The band's light is solid blue: the microphone is on. What it hears goes to your server and from there to Deepgram, a company. Only the wearer's words and registered people's are kept. Tell the people near you. Speak first: the first voice is taken to be yours."
                             : "Start the server on the laptop (python3 server/server.py) and copy its address and pairing code here. With no server address, Listen only counts the sound.")
                    }

                    if !transcript.lines.isEmpty || !transcript.guess.isEmpty {
                        Section {
                            ForEach(transcript.lines) { line in spoken(line, settled: true) }
                            ForEach(transcript.guess) { line in spoken(line, settled: false) }
                        } header: {
                            HStack {
                                Text("Transcript")
                                Spacer()
                                Button("Clear") { transcript.clear() }.font(.caption)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        registering = true
                    } label: {
                        Label("Register a person", systemImage: "person.crop.circle.badge.plus")
                    }
                    NavigationLink {
                        FacesView(watch: watch)
                    } label: {
                        Label("People & faces", systemImage: "person.crop.rectangle.stack")
                    }
                } footer: {
                    Text("Only registered people are recognised, and only conversations with them are recorded. Everyone else's words are left out.")
                }

                if !band.log.isEmpty {
                    Section("Activity") {
                        ForEach(band.log) { entry in
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.text)
                                Spacer()
                                Text(entry.time, format: .dateTime.hour().minute().second())
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Familiar")
            .sheet(isPresented: $registering) { RegisterView(watch: watch) }
            .animation(.default, value: band.phase)
        }
    }

    private func listen(_ on: Bool) {
        if on {
            if !serverAddress.trimmingCharacters(in: .whitespaces).isEmpty {
                transcript.start(server: serverAddress, code: pairingCode)
                // The camera says who is here; the server joins that to the voices.
                if !watch.isOn { watch.start(server: serverAddress, code: pairingCode, useGlasses: useGlasses) }
            }
            band.onAudio = { [transcript] _, opus in transcript.send(opus) }
        } else {
            band.onAudio = nil
            transcript.stop()
            watch.stop()
        }
        Task { await band.setMic(on) }
    }

    private static let speakerColors: [Color] = [.blue, .pink, .green, .orange, .purple, .teal]

    @ViewBuilder
    private func spoken(_ line: TranscriptClient.Line, settled: Bool) -> some View {
        if line.hidden {
            Label("Someone who is not registered spoke. Not kept.", systemImage: "eye.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(transcript.label(for: line.speaker))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(line.speaker.map { Self.speakerColors[$0 % Self.speakerColors.count] } ?? .secondary)
                Text(line.text).foregroundStyle(settled ? .primary : .secondary)
            }
            .padding(.vertical, 2)
        }
    }

    private var inViewText: String {
        let faces = watch.faces
        if case .failed = faces.state { return "problem (see People & faces)" }
        if watch.usingGlasses, case .problem = watch.glasses.status { return "glasses problem (see People & faces)" }
        let sure = faces.inView.filter(\.isSure).map(\.name)
        if !sure.isEmpty { return sure.joined(separator: ", ") }
        if !faces.inView.isEmpty { return "possibly \(faces.inView[0].name)" }
        return faces.strangers > 0 ? "someone not added" : "nobody"
    }

    private var serverText: String {
        switch transcript.state {
        case .idle: return "not used"
        case .connecting: return "connecting…"
        case .live: return "connected"
        case .failed: return "problem"
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.18)).frame(width: 40, height: 40)
                if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: statusIcon).foregroundStyle(statusColor)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Band \(band.band)").font(.headline)
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var connectButton: some View {
        if isLive || isBusy {
            Button(isLive ? "Disconnect" : "Cancel", role: .destructive) { band.disconnect() }
        } else {
            Button("Connect") { band.connect(pretend: pretend) }
                .fontWeight(.semibold)
        }
    }

    private var statusText: String {
        switch band.phase {
        case .idle: return "Not connected"
        case .searching: return "Looking for \(band.bandName)…"
        case .connecting: return "Found it. Connecting…"
        case .verifying: return "Checking it is your band…"
        case .connected: return "Connected"
        case .reconnecting: return "Link lost. Reconnecting…"
        case .failed(let reason): return reason
        }
    }

    private var statusIcon: String {
        switch band.phase {
        case .connected: return "checkmark"
        case .failed: return "exclamationmark.triangle.fill"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    private var statusColor: Color {
        switch band.phase {
        case .connected: return .green
        case .failed: return .orange
        case .idle: return .secondary
        default: return .accentColor
        }
    }

    private var batteryText: String {
        guard let battery = band.battery else { return "—" }
        let state = battery.state == 1 ? ", charging" : battery.state == 2 ? ", charged" : ""
        return "\(battery.percent)%\(state)"
    }

    private var audioText: String {
        guard let started = band.audioStarted else { return "—" }
        let seconds = max(Date().timeIntervalSince(started), 1)
        let rate = Double(band.audioPackets) / seconds
        return String(format: "%.0f packets/s · %.0f kB", rate, Double(band.audioBytes) / 1000)
    }
}

#Preview {
    BandView(band: BandClient(band: BandConfig.teamBand), transcript: TranscriptClient(), watch: FaceWatch(faces: FaceClient(), glasses: GlassesCamera()))
}
