import Observation
import SwiftUI
import VexoBand

/// The wearer registers their own voice: they read a few sentences into the band, and the
/// server keeps a description of how they sound (no recording). After that, Familiar
/// knows which voice is the wearer's in every conversation, whoever speaks first.
@MainActor
@Observable
final class VoiceRegistration {
    enum State: Equatable {
        case idle
        case connecting
        case ready
        case reading(secondsLeft: Int)
        case working
        case failed(String)
    }

    private(set) var state: State = .idle
    /// What the server says: is a voice registered? nil until it has answered.
    private(set) var isRegistered: Bool?
    private(set) var notice: String?

    @ObservationIgnored private var socket: URLSessionWebSocketTask?
    @ObservationIgnored private var reading: Task<Void, Never>?

    static let readingSeconds = 12

    func connect(server: String, code: String) {
        close()
        guard let base = TranscriptClient.url(from: server) else {
            state = .failed("Set the server address first (Settings, then the server row).")
            return
        }
        var request = URLRequest(url: base.appendingPathComponent("voice"))
        request.timeoutInterval = 8
        request.setValue("Bearer " + code.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        state = .connecting
        socket.resume()
        listen(on: socket)
    }

    func close() {
        reading?.cancel()
        reading = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        state = .idle
    }

    /// Switches the band's microphone on, sends what it hears while the wearer reads, then
    /// asks the server to learn the voice.
    func read(with band: BandClient) {
        guard state == .ready, let socket else { return }
        notice = nil
        reading = Task {
            band.onAudio = { _, opus in socket.send(.data(opus)) { _ in } }
            await band.setMic(true)
            for left in stride(from: Self.readingSeconds, to: 0, by: -1) {
                state = .reading(secondsLeft: left)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
            }
            band.onAudio = nil
            await band.setMic(false)
            guard !Task.isCancelled else { return }
            state = .working
            socket.send(.string(#"{"type": "done"}"#)) { _ in }
        }
    }

    func forget() {
        guard state == .ready, let socket else { return }
        state = .working
        socket.send(.string(#"{"type": "forget"}"#)) { _ in }
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
                    self.reading?.cancel()
                    if socket.closeCode.rawValue == 4401 {
                        self.state = .failed("The server did not accept the pairing code.")
                    } else if case .failed = self.state {
                        return
                    } else {
                        self.state = .failed("Could not reach the server. Is it running, and are the phone and the laptop on the same Wi-Fi?")
                    }
                }
            }
        }
    }

    private struct Message: Decodable {
        let type: String
        let registered: Bool?
        let seconds: Double?
        let message: String?
    }

    private func handle(_ text: String) {
        guard let message = try? JSONDecoder().decode(Message.self, from: Data(text.utf8)) else { return }
        switch message.type {
        case "ready":
            isRegistered = message.registered
            state = .ready
        case "voice":
            isRegistered = message.registered
            notice = message.registered == true ? "Your voice is registered." : "Your voice was forgotten."
            state = .ready
        case "error":
            if state == .connecting {
                state = .failed(message.message ?? "The server reported a problem.")
            } else {
                notice = message.message
                state = .ready
            }
        default:
            break
        }
    }
}
