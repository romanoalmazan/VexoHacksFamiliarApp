import AVFoundation
import Foundation
import Observation

/// Sends camera pictures to the Familiar server and hears back which enrolled person is
/// in view. Pictures are compared on the server and not kept. When someone the server is
/// sure about comes into view, the phone says who it is (through the glasses' speakers
/// when they are the phone's Bluetooth audio).
@MainActor
@Observable
final class FaceClient {
    enum State: Equatable {
        case idle
        case connecting
        case live
        case failed(String)
    }

    struct Person: Identifiable, Equatable, Decodable {
        let name: String
        let relationship: String
        /// "sure" or "possible" for someone in view; nil in the list of enrolled people.
        let match: String?
        let photos: Int?
        /// One sentence about the last conversation with them ("Last time, she told you…"),
        /// written by Gemini on the server. Empty until there has been one.
        let recall: String?
        let facts: [String]?
        let followUps: [String]?
        /// When the last conversation with them ended. Only in the list of enrolled people.
        let lastSeen: Moment?

        enum CodingKeys: String, CodingKey {
            case name, relationship, match, photos, recall, facts
            case followUps = "follow_ups"
            case lastSeen = "last_seen"
        }

        var id: String { name }
        var isSure: Bool { match == "sure" }

        /// "This is Maria, your daughter."
        var intro: String {
            relationship.isEmpty ? "This is \(name)." : "This is \(name), your \(relationship)."
        }

        /// "This is Maria, your daughter. Last time, she told you Leo graduated."
        var sentence: String {
            guard let recall, !recall.isEmpty else { return intro }
            return intro + " " + recall
        }
    }

    /// A time from the server, in seconds since 1970. Anything else there reads as "unknown"
    /// instead of spoiling the whole message.
    struct Moment: Equatable, Decodable {
        let date: Date?

        init(from decoder: Decoder) throws {
            let seconds = try? decoder.singleValueContainer().decode(Double.self)
            date = seconds.map { Date(timeIntervalSince1970: $0) }
        }
    }

    private(set) var state: State = .idle
    /// Enrolled people the camera sees right now.
    private(set) var inView: [Person] = []
    /// Faces in view that match nobody enrolled. Nothing is kept about them.
    private(set) var strangers = 0
    private(set) var people: [Person] = []
    /// The last thing worth telling the user: "Added a photo of Maria", or a problem.
    private(set) var notice: String?
    var speaks = true

    @ObservationIgnored private var socket: URLSessionWebSocketTask?
    @ObservationIgnored private var askedAt: Date?                // a picture is with the server
    @ObservationIgnored private var lastSaid: [String: Date] = [:]
    @ObservationIgnored private let voice = AVSpeechSynthesizer()

    /// How long before the same person is announced again.
    private static let quiet: TimeInterval = 120

    func start(server: String, code: String) {
        stop()
        guard let base = TranscriptClient.url(from: server) else {
            state = .failed("That server address does not look right. Copy it from the server's window, for example ws://my-laptop.local:8765")
            return
        }
        var request = URLRequest(url: base.appendingPathComponent("faces"))
        request.timeoutInterval = 8
        request.setValue("Bearer " + code.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        socket.maximumMessageSize = 2 * 1024 * 1024
        self.socket = socket
        state = .connecting
        notice = nil
        socket.resume()
        listen(on: socket)
    }

    func stop() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        inView = []
        strangers = 0
        askedAt = nil
        if state == .live || state == .connecting { state = .idle }
    }

    /// One camera picture. Skipped while the server is still answering the one before.
    func look(_ jpeg: Data) {
        guard state == .live, let socket else { return }
        if let askedAt, Date().timeIntervalSince(askedAt) < 3 { return }
        askedAt = Date()
        socket.send(.data(jpeg)) { _ in }
    }

    func enrol(name: String, relationship: String, jpeg: Data) {
        // Only called from RegisterView once "They agreed to this" is on; the server refuses otherwise.
        send(["type": "enrol", "name": name, "relationship": relationship, "consent": true, "jpeg": jpeg.base64EncodedString()])
    }

    func forget(_ name: String) {
        send(["type": "forget", "name": name])
    }

    /// Asks for the list of registered people again: what is remembered about them changes
    /// a few seconds after a conversation ends.
    func refresh() {
        guard state == .live else { return }
        send(["type": "people"])
    }

    /// Says who this is, now, because the wearer asked ("Say it again").
    func say(_ person: Person) {
        speak(person.sentence)
    }

    #if DEBUG
    /// For automated checks only: behaves as if the server had sent these messages.
    func pretendServerSaid(_ messages: [String]) {
        state = .live
        messages.forEach(handle)
    }
    #endif

    private func send(_ message: [String: Any]) {
        guard state == .live, let socket else {
            notice = "Connect to the server first."
            return
        }
        guard let data = try? JSONSerialization.data(withJSONObject: message), let text = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(text)) { _ in }
    }

    private func listen(on socket: URLSessionWebSocketTask) {
        socket.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.socket === socket else { return }
                switch result {
                case .success(.string(let text)):
                    self.handle(text)
                    self.listen(on: socket)
                case .success:
                    self.listen(on: socket)
                case .failure:
                    self.socket = nil
                    self.inView = []
                    self.strangers = 0
                    if case .failed = self.state { return }
                    if socket.closeCode.rawValue == 4401 {
                        self.state = .failed("The server did not accept the pairing code. Copy it from the server's window.")
                    } else if self.state == .connecting {
                        self.state = .failed("Could not reach the server. Is it running, and are the phone and the laptop on the same Wi-Fi?")
                    } else {
                        self.state = .failed("The connection to the server was lost.")
                    }
                }
            }
        }
    }

    private struct Message: Decodable {
        let type: String
        let people: [Person]?
        let unknown: Int?
        let message: String?
        let name: String?
        let photos: Int?
    }

    private func handle(_ text: String) {
        guard let message = try? JSONDecoder().decode(Message.self, from: Data(text.utf8)) else { return }
        switch message.type {
        case "ready":
            state = .live
            send(["type": "people"])
        case "faces":
            askedAt = nil
            inView = message.people ?? []
            strangers = message.unknown ?? 0
            announce()
        case "enrolled":
            notice = "Added a photo of \(message.name ?? "them")."
            send(["type": "people"])
        case "people":
            people = message.people ?? []
        case "error":
            if state == .connecting {
                state = .failed(message.message ?? "The server reported a problem.")
            } else {
                notice = message.message
            }
        default:
            break
        }
    }

    /// Says a name only when the server is sure, only for one person at a time, and not
    /// again for a while. A wrong name is worse than no name.
    private func announce() {
        let sure = inView.filter(\.isSure)
        guard speaks, sure.count == 1, let person = sure.first else { return }
        if let last = lastSaid[person.name], Date().timeIntervalSince(last) < Self.quiet { return }
        lastSaid[person.name] = Date()
        speak(person.sentence)
    }

    private func speak(_ sentence: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let line = AVSpeechUtterance(string: sentence)
        line.rate = 0.45
        voice.speak(line)
    }
}
