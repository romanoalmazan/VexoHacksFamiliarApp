import Foundation
import Observation

/// Sends the band's sound to the Familiar server and receives the text, labelled by
/// speaker. The app holds no service keys: the server has them.
@MainActor
@Observable
final class TranscriptClient {
    enum State: Equatable {
        case idle
        case connecting
        case live
        case failed(String)
    }

    struct Line: Identifiable, Equatable {
        let id = UUID()
        let speaker: Int?
        var text: String
        /// Someone who is not registered spoke. Their words were withheld by the server
        /// and are not kept anywhere.
        var hidden = false
    }

    /// A short summary of the conversation so far, written by Gemini on the server from the wearer's and
    /// registered people's words only. Replaced whenever the server sends a newer one.
    struct Summary: Equatable {
        let text: String
        let points: [String]
        let followUps: [String]
        let model: String
        let lines: Int
    }

    private(set) var state: State = .idle
    private(set) var summary: Summary?
    /// What was said, settled.
    private(set) var lines: [Line] = []
    /// What is being said right now: a guess that may still change.
    private(set) var guess: [Line] = []
    /// The wearer's speaker number: the first voice heard after Listen went on.
    private(set) var me: Int?
    /// Which speaker number is which enrolled person, worked out by the server from who
    /// the camera saw while that voice spoke. Applies to earlier lines too.
    private(set) var names: [Int: String] = [:]

    /// "You", "Maria", or "Speaker 2" while nobody knows yet.
    func label(for speaker: Int?) -> String {
        guard let speaker else { return "Someone" }
        if speaker == me { return "You" }
        return names[speaker] ?? "Speaker \(speaker + 1)"
    }

    @ObservationIgnored private var socket: URLSessionWebSocketTask?

    /// "ws://Romans-MacBook.local:8765", or just "192.168.1.20:8765".
    static func url(from typed: String) -> URL? {
        var text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "ws://" + text }
        guard let url = URL(string: text), let scheme = url.scheme, ["ws", "wss"].contains(scheme), url.host != nil else { return nil }
        return url
    }

    func start(server: String, code: String) {
        stop()
        guard let url = Self.url(from: server) else {
            state = .failed("That server address does not look right. Copy it from the server's window, for example ws://my-laptop.local:8765")
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Bearer " + code.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        state = .connecting
        guess = []
        summary = nil
        me = nil
        names = [:]
        socket.resume()
        listen(on: socket)
    }

    func stop() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        guess = []
        if state == .live || state == .connecting { state = .idle }
    }

    func clear() {
        lines = []
        guess = []
        summary = nil
    }

    /// The people named in this conversation, in the order they were first named.
    var peopleHeard: [String] {
        var seen: [String] = []
        for line in lines {
            if let speaker = line.speaker, let name = names[speaker], !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    #if DEBUG
    /// Previews and screenshots only (never in a release build): a sample conversation and the summary
    /// Gemini 4 Hydrogen wrote for it, shaped exactly as the server sends them.
    func loadSample() {
        me = 0
        names = [1: "Maria"]
        lines = [
            Line(speaker: 0, text: "Maria! Come in, how was the trip?"),
            Line(speaker: 1, text: "Long, but good. Leo graduated on Friday, I brought you photos."),
            Line(speaker: 0, text: "Oh wonderful. What is he going to do now?"),
            Line(speaker: 1, text: "He starts as a nurse at St. Mary's in January. We'll visit you again at Christmas."),
            Line(speaker: 2, text: "", hidden: true),
            Line(speaker: 0, text: "Tell him I'm proud of him."),
        ]
        summary = Summary(
            text: "Maria is visiting after her trip. You are talking about Leo's graduation, his new job as a nurse, and a Christmas visit.",
            points: ["Leo graduated on Friday and Maria brought photos.",
                     "Leo starts as a nurse at St. Mary's in January.",
                     "They will visit you again at Christmas."],
            followUps: ["Ask to see the photos Maria brought.", "Ask more about Maria's trip."],
            model: "gemini-4-hydrogen", lines: 5)
    }
    #endif

    /// One Opus packet from the band. Dropped until the server says it is ready.
    func send(_ opus: Data) {
        guard state == .live, let socket else { return }
        socket.send(.data(opus)) { _ in }
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
                    self.guess = []
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
        struct Segment: Decodable { let speaker: Int?; let text: String; let hidden: Bool? }
        let type: String
        let final: Bool?
        let segments: [Segment]?
        let message: String?
        let me: Int?
        let names: [String: String]?
        let summary: String?
        let points: [String]?
        let follow_ups: [String]?
        let model: String?
        let lines: Int?
    }

    /// Adds settled lines, joining what the same voice says in a row. Unregistered
    /// voices in a row become one "not kept" line, whoever they were.
    private func append(_ pieces: [Line]) {
        for piece in pieces {
            guard let last = lines.indices.last else { lines.append(piece); continue }
            if piece.hidden && lines[last].hidden { continue }
            if !piece.hidden && !lines[last].hidden && lines[last].speaker == piece.speaker {
                lines[last].text += " " + piece.text
            } else {
                lines.append(piece)
            }
        }
    }

    private func handle(_ text: String) {
        guard let message = try? JSONDecoder().decode(Message.self, from: Data(text.utf8)) else { return }
        switch message.type {
        case "ready":
            state = .live
        case "error":
            state = .failed(message.message ?? "The server reported a problem.")
        case "speakers":
            me = message.me
            names = Dictionary(uniqueKeysWithValues: (message.names ?? [:]).compactMap { key, name in Int(key).map { ($0, name) } })
        case "transcript":
            let pieces = (message.segments ?? []).map { Line(speaker: $0.speaker, text: $0.text, hidden: $0.hidden == true) }
            guard message.final == true else { guess = pieces; return }
            guess = []
            append(pieces)
        case "summary":
            if let text = message.summary, !text.isEmpty {
                summary = Summary(text: text, points: message.points ?? [], followUps: message.follow_ups ?? [],
                                  model: message.model ?? "Gemini", lines: message.lines ?? lines.count)
            }
        case "all":
            // A voice was just recognised as a registered person: the server sends the
            // whole conversation again, now with what that voice said earlier.
            lines = []
            append((message.segments ?? []).map { Line(speaker: $0.speaker, text: $0.text, hidden: $0.hidden == true) })
        default:
            break
        }
    }
}
