import Foundation
import Observation
import SwiftUI
import UIKit
import VexoBand

/// What the screens share: the band, the two connections to the server, which tab and
/// sheet are showing, and the conversation that ended last.
@MainActor
@Observable
final class AppModel {
    enum Tab: Hashable { case now, people, recaps, privacy }

    /// The four things that are set up once and changed from Settings.
    enum Device: Hashable { case server, band, camera, voice }

    enum Sheet: Identifiable, Equatable {
        case settings
        case device(Device)
        case register(name: String?)
        case showSomeone
        case recognized(name: String)
        case possible(name: String)

        var id: String {
            switch self {
            case .settings: return "settings"
            case .device(let device): return "device-\(device)"
            case .register(let name): return "register-\(name ?? "")"
            case .showSomeone: return "show-someone"
            case .recognized(let name): return "recognized-\(name)"
            case .possible(let name): return "possible-\(name)"
            }
        }
    }

    struct Toast: Equatable {
        var title: String
        var detail: String?
        var initials: String?
    }

    /// What one Listen left behind, as the phone saw it.
    struct Conversation: Codable, Equatable {
        var people: [String]        // registered people who took part
        var kept: Int               // lines shown: the wearer's and registered people's
        var hidden: Int             // stretches of speech from people who are not registered
        var started: Date
        var ended: Date
    }

    let band: BandClient
    let transcript: TranscriptClient
    let watch: FaceWatch
    var faces: FaceClient { watch.faces }
    var glasses: GlassesCamera { watch.glasses }

    var tab: Tab = .now
    /// The person open in the People tab, if any.
    var peoplePath: [String] = []
    var sheet: Sheet?
    private(set) var toast: Toast?
    private(set) var last: Conversation?
    /// When Listen went on, while it is on.
    private(set) var listenStarted: Date?
    /// Listen was switched on here and not off since.
    private(set) var wantsToListen = false

    /// Listen is on. Stays true through a dropped Bluetooth link, while the band is found
    /// again and its microphone comes back by itself.
    var isListening: Bool { wantsToListen || band.micOn }
    /// For automated checks only: launch with -demoScreen <name> to open on that screen.
    let demoScreen: String?

    /// The server address is being typed: do not connect behind the typing.
    @ObservationIgnored var editingServer = false
    @ObservationIgnored private var usedServer = false
    @ObservationIgnored private var toastTimer: Task<Void, Never>?

    init(band: BandClient, transcript: TranscriptClient, watch: FaceWatch) {
        self.band = band
        self.transcript = transcript
        self.watch = watch
        let defaults = UserDefaults.standard
        if let says = defaults.object(forKey: "sayNames") as? Bool { watch.faces.speaks = says }
        if let saved = defaults.data(forKey: "lastConversation") {
            last = try? JSONDecoder().decode(Conversation.self, from: saved)
        }
        // A phone that already has a server address was set up before there was a setup.
        if defaults.object(forKey: "setupDone") == nil, !(defaults.string(forKey: "serverAddress") ?? "").isEmpty {
            defaults.set(true, forKey: "setupDone")
        }
        let arguments = ProcessInfo.processInfo.arguments
        if let at = arguments.firstIndex(of: "-demoScreen"), arguments.count > at + 1 {
            demoScreen = arguments[at + 1]
        } else {
            demoScreen = nil
        }
        switch demoScreen {
        case "people": tab = .people
        case "recaps": tab = .recaps
        case "privacy": tab = .privacy
        case "settings": sheet = .settings
        case "register": sheet = .register(name: nil)
        case "show-someone": sheet = .showSomeone
        case "band": sheet = .device(.band)
        case "camera": sheet = .device(.camera)
        case "voice": sheet = .device(.voice)
        case "server": sheet = .device(.server)
        case "recognized": sheet = .recognized(name: "Maria")
        case "possible": sheet = .possible(name: "Leo")
        case "profile": tab = .people; peoplePath = ["Maria"]
        default: break
        }
    }

    // MARK: the server

    var serverAddress: String {
        (UserDefaults.standard.string(forKey: "serverAddress") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var pairingCode: String { UserDefaults.standard.string(forKey: "pairingCode") ?? "" }
    var hasServer: Bool { !serverAddress.isEmpty }
    private var useGlasses: Bool { UserDefaults.standard.bool(forKey: "useGlasses") }

    /// "Say who it is out loud", remembered between launches.
    var saysNames: Bool {
        get { faces.speaks }
        set {
            faces.speaks = newValue
            UserDefaults.standard.set(newValue, forKey: "sayNames")
        }
    }

    /// Connects to the server without a camera, so the registered people can be listed,
    /// registered and forgotten while nothing is being looked at.
    func reach() {
        guard hasServer, !watch.isOn else { return }
        if faces.state == .live || faces.state == .connecting { return }
        faces.start(server: serverAddress, code: pairingCode)
    }

    /// Runs for the life of the app. While no camera is on it keeps the connection to the
    /// server open and the people list fresh: what is remembered about someone changes a
    /// few seconds after a conversation ends.
    func keepInTouch() async {
        reach()
        var waited = 0
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !watch.isOn, !editingServer else { continue }
            switch faces.state {
            case .live:
                faces.refresh()
                waited = 0
            case .connecting:
                break
            case .idle:
                // The camera was switched off, and the connection with it: open it again.
                if UIApplication.shared.applicationState == .active { reach() }
            case .failed:
                // Try again, but not every time, so a wrong code is not hammered.
                waited += 1
                if waited >= 3, UIApplication.shared.applicationState == .active {
                    waited = 0
                    reach()
                }
            }
        }
    }

    // MARK: listening and looking

    /// Listen on: the band's microphone, the words (through the server) and the camera.
    /// With no server address, Listen only counts the sound, as a check of the band.
    func listen(_ on: Bool) {
        wantsToListen = on
        if on {
            transcript.clear()
            listenStarted = Date()
            usedServer = hasServer
            if hasServer {
                transcript.start(server: serverAddress, code: pairingCode)
                // The camera says who is here; the server joins that to the voices.
                if !watch.isOn { watch.start(server: serverAddress, code: pairingCode, useGlasses: useGlasses) }
            }
            band.onAudio = { [transcript] _, opus in transcript.send(opus) }
        } else {
            remember()
            band.onAudio = nil
            transcript.stop()
            watch.stop()
            listenStarted = nil
            reach()         // the people list, and what Gemini is about to write, need the server
        }
        Task { await band.setMic(on) }
    }

    /// The camera alone, without the band: to check that faces are recognised.
    func look(_ on: Bool) {
        if on {
            guard hasServer else { return }
            watch.start(server: serverAddress, code: pairingCode, useGlasses: useGlasses)
        } else {
            watch.stop()
            reach()
        }
    }

    /// Notes what the conversation left behind. The server applies the same rule when the
    /// sound stops: nothing at all is kept unless a registered person took part.
    private func remember() {
        guard usedServer, let started = listenStarted else { return }
        let lines = transcript.lines
        guard !lines.isEmpty else { return }
        let people = transcript.peopleHeard
        let hidden = lines.filter(\.hidden).count
        let conversation = Conversation(people: people, kept: people.isEmpty ? 0 : lines.count - hidden,
                                        hidden: hidden, started: started, ended: Date())
        last = conversation
        if let data = try? JSONEncoder().encode(conversation) {
            UserDefaults.standard.set(data, forKey: "lastConversation")
        }
        show(people.isEmpty
             ? Toast(title: "Nothing was kept", detail: "Nobody registered took part.")
             : Toast(title: "Conversation saved as text", detail: "\(people.joined(separator: ", ")) · no audio kept"))
    }

    // MARK: people

    func person(named name: String) -> FaceClient.Person? {
        faces.people.first { $0.name == name }
    }

    /// Deletes a person's face data and profile on the server. False when there is no
    /// connection to ask over.
    @discardableResult
    func forget(_ name: String) -> Bool {
        guard faces.state == .live else {
            show(Toast(title: "Not connected to the server", detail: "Nothing was deleted."))
            return false
        }
        faces.forget(name)
        show(Toast(title: "Forgot \(name)", detail: "Face data and profile deleted on the server."))
        return true
    }

    func forgetEveryone() {
        guard faces.state == .live else {
            show(Toast(title: "Not connected to the server", detail: "Nothing was deleted."))
            return
        }
        for person in faces.people { faces.forget(person.name) }
        show(Toast(title: "Everyone forgotten", detail: "All face data and profiles deleted."))
    }

    /// Opens a person's profile in the People tab, from anywhere.
    func open(person name: String) {
        sheet = nil
        tab = .people
        peoplePath = [name]
    }

    // MARK: toasts

    func show(_ toast: Toast) {
        toastTimer?.cancel()
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { self.toast = toast }
        toastTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { self?.toast = nil }
        }
    }
}
