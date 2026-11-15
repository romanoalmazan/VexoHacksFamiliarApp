import SwiftUI
import VexoBand

// The Now tab (ready, and listening), and the two screens that open from who is in view:
// "This is Maria" and "Might be Leo".

// MARK: - 05 / 06 · Now

struct NowScreen: View {
    let model: AppModel

    @AppStorage("serverAddress") private var serverAddress = ""
    @AppStorage("useGlasses") private var useGlasses = false
    @AppStorage("voiceRegistered") private var voiceRegistered = false
    @AppStorage("showCameraPreview") private var showPreview = true

    private var band: BandClient { model.band }
    private var transcript: TranscriptClient { model.transcript }
    private var watch: FaceWatch { model.watch }
    private var faces: FaceClient { model.faces }
    private var hasServer: Bool { !serverAddress.trimmingCharacters(in: .whitespaces).isEmpty }
    private var bandLive: Bool { band.phase == .connected }

    private var bandBusy: Bool {
        switch band.phase {
        case .searching, .connecting, .verifying, .reconnecting: return true
        default: return false
        }
    }

    var body: some View {
        Screen {
            if model.isListening { live } else { ready }
        }
        .animation(.spring(duration: 0.45), value: model.isListening)
        .animation(.spring(duration: 0.45), value: faces.inView)
    }

    // MARK: ready

    @ViewBuilder
    private var ready: some View {
        TitleRow("Now", model: model) {
            Chip {
                Icon("band", size: 16)
                Text(bandLive ? (band.isPretend ? "Pretend" : "Band \(band.band)") : "No band")
            }
        }

        if watch.isOn {
            inView.padding(.top, 20)
            cameraCard.padding(.top, 12)
            Button("Stop looking") { model.look(false) }
                .buttonStyle(CapsuleButton(kind: .secondary, height: 48))
                .padding(.top, 12)
        }

        VStack(alignment: .leading, spacing: 0) {
            BreathingMic().padding(.leading, 16)
            Text(bandLive ? "Ready when you are" : "A few things first")
                .font(.title2.weight(.bold))
                .padding(.top, 30)
            Text(readyText)
                .font(.subheadline).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Button {
                if bandLive { model.listen(true) } else { model.sheet = .device(.band) }
            } label: {
                if bandLive {
                    Label("Listen", systemImage: "mic.fill")
                } else {
                    Text(bandBusy ? "Connecting the band…" : "Connect the band")
                }
            }
            .buttonStyle(CapsuleButton())
            .padding(.top, 20)
            if hasServer && !watch.isOn {
                Button("Just look for faces") { model.look(true) }
                    .buttonStyle(CapsuleButton(kind: .text))
                    .padding(.top, 6)
            }
        }
        .padding(.top, 32).padding(.horizontal, 20).padding(.bottom, 20)
        .card()
        .padding(.top, 20)

        SectionTitle("Connections").padding(.top, 26)
        VStack(spacing: 0) {
            ValueRow(icon: "dot.radiowaves.left.and.right", title: "Server", value: serverValue.text,
                     valueColor: serverValue.ok ? Theme.greenInk : Theme.dangerInk) { model.sheet = .device(.server) }
            Hairline(inset: 58)
            ValueRow(icon: "band", title: "Band", value: bandValue,
                     valueColor: bandLive ? Theme.greenInk : bandBusy ? Theme.muted : Theme.dangerInk) { model.sheet = .device(.band) }
            Hairline(inset: 58)
            ValueRow(icon: useGlasses ? "eyeglasses" : "eye", title: "Camera", value: useGlasses ? "Meta glasses" : "iPhone",
                     valueColor: Theme.greenInk) { model.sheet = .device(.camera) }
        }
        .card()
        .padding(.top, 8)

        if let last = model.last {
            Callout(icon: "doc.text", title: "Last conversation",
                    detail: last.people.isEmpty ? "Nothing was kept" : last.people.joined(separator: ", ")) {
                model.tab = .recaps
            }
            .padding(.top, 14)
        }
    }

    private var readyText: String {
        if !bandLive {
            if case .failed(let reason) = band.phase { return reason }
            return "Connect the band to start. A server and a camera add the words, names and faces."
        }
        if !hasServer {
            return "No server yet: Listen only checks that the band’s sound arrives. Set a server to get words, names and faces."
        }
        return "Tap Listen when someone arrives. Familiar looks for faces and follows the conversation until you stop."
    }

    private var serverValue: (text: String, ok: Bool) {
        guard hasServer else { return ("Not set", false) }
        if transcript.state == .live { return ("Connected", true) }
        switch faces.state {
        case .live: return ("Connected", true)
        case .connecting: return ("Connecting…", false)
        case .idle, .failed: return ("Not connected", false)
        }
    }

    private var bandValue: String {
        switch band.phase {
        case .connected: return band.isPretend ? "Pretend band" : "Band \(band.band)"
        case .reconnecting: return "Reconnecting…"
        case .searching, .connecting, .verifying: return "Connecting…"
        case .failed: return "Problem"
        case .idle: return "Not connected"
        }
    }

    // MARK: listening

    @ViewBuilder
    private var live: some View {
        TitleRow("Now", model: model) {
            if band.micOn {
                Chip(.live) {
                    LiveDot()
                    Text("Listening")
                }
            } else {
                // The link to the band dropped, or its microphone has not started.
                Chip(.paused) {
                    Text(bandLive ? "Microphone is off" : bandBusy ? "Finding the band…" : "Band not connected")
                }
            }
        }

        if !band.micOn, case .failed(let reason) = band.phase {
            ProblemNote(reason).padding(.top, 12)
        }

        inView.padding(.top, 20)
        cameraCard.padding(.top, 12)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Live transcript").font(.body.weight(.semibold))
                Spacer()
                if let started = model.listenStarted {
                    Text("since \(started, format: .dateTime.hour().minute())")
                        .font(.footnote.monospacedDigit()).foregroundStyle(Theme.muted)
                }
            }
            Text(!hasServer ? "No server set, so there are no words: only the sound is counted."
                 : voiceRegistered ? "“You” is found by your registered voice."
                 : "“You” is the first voice heard after Listen. Speak first.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            if hasServer {
                TranscriptLines(transcript: transcript, last: 8).padding(.top, 10)
            }
        }
        .card(padding: 16)
        .padding(.top, 12)

        if case .failed(let reason) = transcript.state {
            ProblemNote(reason).padding(.top, 12)
        }

        Button {
            model.listen(false)
            if hasServer { model.tab = .recaps }
        } label: {
            Label("Stop listening", systemImage: "stop.fill")
        }
        .buttonStyle(CapsuleButton(kind: .danger))
        .padding(.top, 12)

        Text("The band’s light is solid blue: the microphone is on. What it hears goes to your server and from there to Deepgram, a company. Only your words and registered people’s are kept. Tell the people near you.")
            .font(.footnote).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10).padding(.horizontal, 4)

        SectionTitle("Sound from the band").padding(.top, 22)
        VStack(spacing: 0) {
            DetailRow(label: "Server", value: serverText)
            Hairline(inset: 16)
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                DetailRow(label: "Sound arriving", value: audioText)
            }
            Hairline(inset: 16)
            DetailRow(label: "Packets lost", value: "\(band.audioLost)")
        }
        .card()
        .padding(.top, 8)
    }

    private var serverText: String {
        switch transcript.state {
        case .idle: return "not used"
        case .connecting: return "connecting…"
        case .live: return "connected"
        case .failed: return "problem"
        }
    }

    private var audioText: String {
        guard let started = band.audioStarted else { return "—" }
        let seconds = max(Date().timeIntervalSince(started), 1)
        let rate = Double(band.audioPackets) / seconds
        return String(format: "%.0f packets/s · %.0f kB", rate, Double(band.audioBytes) / 1000)
    }

    // MARK: who the camera sees

    @ViewBuilder
    private var inView: some View {
        if faces.inView.isEmpty {
            let looking = looking
            HStack(spacing: 12) {
                Tile(looking.icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(looking.title).font(.body.weight(.semibold))
                    Text(looking.detail).font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .card(padding: 16)
        } else {
            VStack(spacing: 10) {
                ForEach(faces.inView.filter(\.isSure)) { person in
                    Button {
                        model.sheet = .recognized(name: person.name)
                    } label: {
                        InViewCard(person: person)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("In view: \(person.sentence)")
                }
                ForEach(faces.inView.filter { !$0.isSure }) { person in
                    Button {
                        model.sheet = .possible(name: person.name)
                    } label: {
                        HStack(spacing: 12) {
                            Avatar(look: .unknown)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Might be \(person.name)").font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                Text("Not sure enough to say out loud.").font(.subheadline).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 0)
                            Icon("chevron.right", size: 16, weight: .semibold).foregroundStyle(Theme.outline)
                        }
                        .padding(12)
                        .card()
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
    }

    /// Nobody registered is in view: why, in a few words.
    private var looking: (icon: String, title: String, detail: String) {
        guard watch.isOn else {
            return ("eye.slash", "Not looking for faces", "Faces and names need a server. Listen is only checking the band’s sound.")
        }
        if case .failed(let reason) = faces.state {
            return ("exclamationmark.triangle", "Faces are not being looked for", reason)
        }
        if watch.usingGlasses {
            switch watch.glasses.status {
            case .starting: return ("eyeglasses", "Connecting to the glasses…", "Only registered people get a name.")
            case .waiting: return ("eyeglasses", "Waiting for the glasses’ camera", "Put them on, unfolded.")
            case .paused: return ("pause.circle", "The glasses paused the camera", "Tap the temple to carry on.")
            case .problem(let reason): return ("exclamationmark.triangle", "The glasses’ camera has a problem", reason)
            case .off, .streaming: break
            }
        } else if let problem = watch.phoneProblem {
            return ("exclamationmark.triangle", "The iPhone’s camera has a problem", problem)
        }
        if faces.state == .connecting {
            return ("eye", "Connecting to the server…", "Only registered people get a name.")
        }
        if faces.strangers > 0 {
            return ("person.fill.questionmark", "Someone who has not been added", "Nothing is kept about them. Only registered people get a name.")
        }
        return ("eye", "Looking for faces", "Using the \(watch.usingGlasses ? "Meta glasses" : "iPhone camera"). Only registered people get a name.")
    }

    @ViewBuilder
    private var cameraCard: some View {
        if watch.isOn {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    showPreview.toggle()
                } label: {
                    HStack {
                        Text("What the camera sees").font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Icon(showPreview ? "chevron.up" : "chevron.down", size: 14, weight: .semibold).foregroundStyle(Theme.subtle)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(showPreview ? "Hides the picture" : "Shows the picture")
                if showPreview {
                    CameraLook(watch: watch).padding(.top, 12)
                }
            }
            .card(padding: 16)
        }
    }
}

/// The graphite card for someone the camera is sure about.
struct InViewCard: View {
    let person: FaceClient.Person

    var body: some View {
        MatchCard {
            HStack {
                TalkingLabel(text: "In view")
                Spacer()
                ConfidenceChip(sure: true)
            }
            HStack(spacing: 4) {
                Avatar(name: person.name, look: .ring, live: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This is \(person.name)").font(.title2.weight(.bold))
                    if !person.relationship.isEmpty {
                        Text("Your \(person.relationship)").font(.subheadline).foregroundStyle(Theme.skyText)
                    }
                }
                Spacer(minLength: 0)
                Icon("chevron.right", size: 16, weight: .semibold).foregroundStyle(Theme.navyRing)
            }
            .padding(.top, 4)
            if let recall = person.recall, !recall.isEmpty {
                Rectangle().fill(Theme.navyLine).frame(height: 0.5).padding(.top, 6)
                Text("Last time").font(.footnote.weight(.medium)).foregroundStyle(Theme.skyText).padding(.top, 14)
                Text(Recall.body(recall))
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }
}

enum Recall {
    /// "Last time, she told you about Leo." under a "Last time" heading reads better as
    /// "She told you about Leo."
    static func body(_ recall: String) -> String {
        for start in ["Last time, ", "Last time "] where recall.hasPrefix(start) {
            let rest = recall.dropFirst(start.count)
            return rest.prefix(1).uppercased() + rest.dropFirst()
        }
        return recall
    }
}

/// What the camera in use sees, live.
struct CameraLook: View {
    let watch: FaceWatch
    var height: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if watch.usingGlasses {
                if let picture = watch.glasses.preview {
                    // The whole picture, uncropped: this is exactly what the server is sent.
                    Image(uiImage: picture)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: height + 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Label("Waiting for the glasses’ camera. Put them on, unfolded.", systemImage: "eyeglasses")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
                if case .problem(let reason) = watch.glasses.status {
                    ProblemNote(reason)
                }
            } else if let problem = watch.phoneProblem {
                Text(problem).font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                CameraPreview(session: watch.phone.session)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            watch.phone.flip()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .padding(10)
                                .background(.thinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityLabel("Switch camera")
                    }
            }
        }
    }
}

/// What was said: a name on each line, and "not kept" where someone unregistered spoke.
struct TranscriptLines: View {
    let transcript: TranscriptClient
    /// Show only this many of the newest settled lines, or all of them.
    var last: Int? = nil

    private var settled: [TranscriptClient.Line] {
        guard let last else { return transcript.lines }
        return Array(transcript.lines.suffix(last))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if transcript.lines.isEmpty && transcript.guess.isEmpty {
                Text("Words appear here as people talk.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(settled) { line in spoken(line, settled: true) }
            ForEach(transcript.guess) { line in spoken(line, settled: false) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func spoken(_ line: TranscriptClient.Line, settled: Bool) -> some View {
        if line.hidden {
            HStack(spacing: 8) {
                Icon("eye.slash", size: 15)
                Text("Someone who is not registered spoke. Not kept.").italic()
            }
            .font(.footnote)
            .foregroundStyle(Theme.subtle)
        } else {
            let mine = line.speaker != nil && line.speaker == transcript.me
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(transcript.label(for: line.speaker))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .foregroundStyle(mine ? Theme.ink2 : Theme.blue)
                    .background(mine ? Theme.fill : Theme.tint, in: Capsule())
                Text(line.text)
                    .font(.subheadline)
                    .foregroundStyle(settled ? Theme.ink : Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The microphone in rings, breathing slowly: ready to start.
struct BreathingMic: View {
    @State private var out = false
    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        Icon("mic", size: 28)
            .foregroundStyle(Theme.blue)
            .frame(width: 56, height: 56)
            .background(Theme.tint, in: Circle())
            .overlay {
                Circle().stroke(Theme.ring1, lineWidth: 1.5).padding(-7.75)
                Circle().stroke(Theme.line, lineWidth: 1.5).padding(-15.75)
            }
            .scaleEffect(out && !still ? 1.06 : 1)
            .animation(still ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: out)
            .onAppear { out = true }
            .accessibilityHidden(true)
    }
}

/// A large title, something small on the right, and the button that opens Settings.
struct TitleRow<Trailing: View>: View {
    let title: String
    let model: AppModel
    let trailing: Trailing

    init(_ title: String, model: AppModel, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.model = model
        self.trailing = trailing()
    }

    var body: some View {
        let connected = model.faces.state == .live || model.transcript.state == .live
        HStack(spacing: 8) {
            Text(title).font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
            Button {
                model.sheet = .settings
            } label: {
                Icon("person", size: 20, weight: .semibold)
                    .foregroundStyle(connected ? Color.white : Theme.ink2)
                    .frame(width: 36, height: 36)
                    .background(connected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.fill), in: Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }
}

extension TitleRow where Trailing == EmptyView {
    init(_ title: String, model: AppModel) {
        self.init(title, model: model) { EmptyView() }
    }
}

// MARK: - 08 · Recognized

/// The server matched a registered face and is sure.
struct RecognizedScreen: View {
    let model: AppModel
    let name: String

    @Environment(\.dismiss) private var dismiss

    private var seen: FaceClient.Person? { model.faces.inView.first { $0.name == name && $0.isSure } }
    private var known: FaceClient.Person? { model.person(named: name) }
    private var person: FaceClient.Person? { seen ?? known }
    private var relationship: String { person?.relationship ?? "" }

    private var recall: String {
        if let recall = seen?.recall, !recall.isEmpty { return recall }
        return known?.recall ?? ""
    }

    var body: some View {
        Screen {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold)).foregroundStyle(Theme.blue)
                    .frame(height: 44)
            }
            .padding(.top, 8)

            MatchCard(large: true) {
                HStack {
                    if seen != nil {
                        TalkingLabel(text: "In view")
                        Spacer()
                        ConfidenceChip(sure: true)
                    } else {
                        Text("Not in view now").font(.footnote.weight(.semibold)).foregroundStyle(Theme.skyText)
                        Spacer()
                    }
                }
                Avatar(name: name, look: .ring, live: seen != nil).padding(.top, 10).padding(.leading, -6)
                Text("This is \(name)").font(.title.weight(.bold)).padding(.top, 6)
                if !relationship.isEmpty {
                    Text("Your \(relationship)").font(.subheadline).foregroundStyle(Theme.skyText).padding(.top, 2)
                }
                if !recall.isEmpty {
                    Rectangle().fill(Theme.navyLine).frame(height: 0.5).padding(.top, 18)
                    Text("LAST TIME").font(.footnote.weight(.medium)).foregroundStyle(Theme.skyText).padding(.top, 16)
                    Text(Recall.body(recall))
                        .font(.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                if let asks = known?.followUps, !asks.isEmpty {
                    Text("You could ask").font(.footnote.weight(.medium)).foregroundStyle(Theme.skyText).padding(.top, 18)
                    ForEach(asks, id: \.self) { ask in
                        Text(ask).font(.callout.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.top, 4)
        } bottom: {
            Button {
                if let person { model.faces.say(person) }
            } label: {
                Label("Say it again", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(CapsuleButton())
            .disabled(person == nil)
            Button("About \(name)") { model.open(person: name) }
                .buttonStyle(CapsuleButton(kind: .secondary))
        }
    }
}

// MARK: - 09 · Possible match

/// The server answered "possible": no name is said out loud, and that voice's words stay
/// hidden, until the camera is sure.
struct PossibleMatchScreen: View {
    let model: AppModel
    let name: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Screen {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold)).foregroundStyle(Theme.blue)
                    .frame(height: 44)
            }
            .padding(.top, 8)

            Avatar(look: .unknown).padding(.top, 8)
            Text("Might be \(name)").font(.title.weight(.bold)).padding(.top, 12)
            ConfidenceChip(sure: false, onNavy: false).padding(.top, 10)
            Text("Familiar isn’t sure who this is, so it didn’t say a name. What they say stays hidden, and isn’t kept, until the camera is sure it is \(name).")
                .font(.body).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Icon("lock", size: 18).foregroundStyle(Theme.blue)
                    Text("Details hidden until the camera is sure").font(.subheadline.weight(.semibold))
                }
                SkeletonLines()
            }
            .card(padding: 16)
            .padding(.top, 20)

            Text("More photos of \(name) make the camera surer: straight on, a little left, a little right.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10).padding(.leading, 4)
        } bottom: {
            Button("Add photos of \(name)") { model.sheet = .register(name: name) }
                .buttonStyle(CapsuleButton())
            Button("It’s someone else") { dismiss() }
                .buttonStyle(CapsuleButton(kind: .secondary))
        }
    }
}
