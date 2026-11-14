// The app's one connection to its band: connect, check it is the right band, set the
// clock, start the streams, and come back by itself after a dropped link.
import Foundation
import Observation

public struct BandError: Error, Equatable, LocalizedError {
    public let code: String
    public let message: String
    public var errorDescription: String? { message }
}

public struct BandLogEntry: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let time: Date
    public let text: String
}

@MainActor
@Observable
public final class BandClient {
    public enum Phase: Equatable {
        case idle
        case searching
        case connecting
        case verifying
        case connected
        case reconnecting
        case failed(String)
    }

    /// The team's band number. The client never talks to any other band.
    public let band: Int
    public var bandName: String { VexoContract.name(forBand: band) }

    public private(set) var phase: Phase = .idle
    public private(set) var isPretend = false
    public private(set) var info: BandInfo?
    public private(set) var battery: BatteryReading?
    public private(set) var rssi: Int?
    public private(set) var log: [BandLogEntry] = []

    /// The microphone (AUDIO stream). While it is on the band's light is solid blue.
    public private(set) var micOn = false
    public private(set) var audioPackets = 0
    public private(set) var audioLost = 0
    public private(set) var audioBytes = 0
    public private(set) var audioStarted: Date?

    /// Every Opus packet from the band's microphone (16 kHz mono, 20 ms each).
    @ObservationIgnored public var onAudio: ((_ seq: UInt16, _ opus: Data) -> Void)?
    /// Taps and other gestures, as they happen.
    @ObservationIgnored public var onGesture: ((BandGesture) -> Void)?

    @ObservationIgnored private var link: BandLink?
    @ObservationIgnored private var seq: UInt8 = 0
    @ObservationIgnored private var pending: (seq: UInt8, opcode: UInt8, done: CheckedContinuation<Response, Error>)?
    @ObservationIgnored private var tail: Task<Void, Never>?
    @ObservationIgnored private var wantMic = false
    @ObservationIgnored private var lastAudioSeq: UInt16?
    @ObservationIgnored private var everConnected = false

    public init(band: Int) {
        precondition((1...999).contains(band), "Band numbers are 1 to 999.")
        self.band = band
    }

    // MARK: connect / disconnect

    public func connect(pretend: Bool) {
        guard link == nil else { return }
        isPretend = pretend
        everConnected = false
        open(searchSeconds: 20)
    }

    public func disconnect() {
        wantMic = false
        guard let link else { phase = .idle; return }
        link.close()
    }

    private func open(searchSeconds: TimeInterval) {
        let link: BandLink = isPretend ? SimLink(band: band) : BLELink(band: band)
        self.link = link
        link.onEvent = { [weak self] in self?.handle($0) }
        link.onFrame = { [weak self] in self?.receive($0) }
        link.open(searchSeconds: searchSeconds)
    }

    private func handle(_ event: LinkEvent) {
        switch event {
        case .searching:
            if phase != .reconnecting { phase = .searching }
        case .connecting:
            if phase != .reconnecting { phase = .connecting }
        case .ready:
            if phase != .reconnecting { phase = .verifying }
            Task { await self.setUp() }
        case .unavailable(let text):
            drop()
            phase = .failed(text)
        case .notFound:
            drop()
            phase = .failed(everConnected
                ? "Lost \(bandName) and could not find it again. Double-tap the band and press Connect."
                : "Could not see \(bandName). Double-tap the band (it blinks blue for 60 seconds), make sure nothing else is connected to it (the dashboard, a teammate's laptop), then try again.")
        case .closed(let byUs):
            let wasLive = phase == .connected || phase == .reconnecting
            drop()
            if byUs {
                phase = .idle
                note("Disconnected.")
            } else if wasLive {
                // The band can be found again for 2 minutes after a dropped link.
                phase = .reconnecting
                note("Link lost. Looking for the band again...")
                open(searchSeconds: 120)
            } else if case .failed = phase {
                // keep the reason we already gave
            } else {
                phase = .failed("Could not connect to \(bandName). Double-tap the band and try again.")
            }
        }
    }

    private func drop() {
        link?.onEvent = nil
        link?.onFrame = nil
        link = nil
        micOn = false
        rssi = nil
        lastAudioSeq = nil
        if let pending {
            self.pending = nil
            pending.done.resume(throwing: BandError(code: "not-connected", message: "The band is not connected."))
        }
    }

    /// Runs after every connect and reconnect: the band forgets everything when the link closes.
    private func setUp() async {
        do {
            let info = try BandInfo(data: try await command(.getInfo).data)
            guard info.bandNumber == band else {
                // Not ours: change nothing on it and leave at once.
                phase = .failed("Another band answered (number \(info.bandNumber)), not \(bandName). Nothing was changed on it. Check the number on your band's bag.")
                link?.close()
                return
            }
            self.info = info
            _ = try? await command(.timeSet, Command.timeSet(unixMs: UInt64(Date().timeIntervalSince1970 * 1000)))
            if let reply = try? await command(.batteryGet) { battery = try? BatteryReading(data: reply.data) }
            var streams: StreamMask = [.event, .battery, .link]
            if wantMic { streams.insert(.audio) }
            try await start(streams)
            let back = phase == .reconnecting
            phase = .connected
            everConnected = true
            note(back ? "Reconnected to \(bandName)." : "Connected to \(bandName), firmware \(info.firmware).")
        } catch {
            guard link != nil else { return }
            phase = .failed("Connected, but the band did not answer: \(error.localizedDescription)")
            link?.close()
        }
    }

    private func start(_ streams: StreamMask) async throws {
        let reply = try await command(.streamStart, Command.streamMask(streams))
        let active = StreamMask(rawValue: UInt16(reply.data[reply.data.startIndex]) | UInt16(reply.data[reply.data.startIndex + 1]) << 8)
        if streams.contains(.audio) { markMic(active.contains(.audio)) }
    }

    // MARK: what the app can ask for

    /// Switch the band's microphone on or off. On: the band's light turns solid blue and
    /// every packet goes to `onAudio`.
    public func setMic(_ on: Bool) async {
        wantMic = on
        guard phase == .connected else { return }
        do {
            if on {
                try await start(.audio)
            } else {
                _ = try await command(.streamStop, Command.streamMask(.audio))
                markMic(false)
            }
        } catch {
            wantMic = micOn
            note("Microphone: \(error.localizedDescription)")
        }
    }

    /// Blink the band's light white for a few seconds, to see which band this is.
    public func identify() async {
        do {
            _ = try await command(.identify, Command.identify(seconds: 3))
        } catch {
            note("Blink: \(error.localizedDescription)")
        }
    }

    private func markMic(_ on: Bool) {
        if on, !micOn {
            audioPackets = 0; audioLost = 0; audioBytes = 0
            audioStarted = Date()
            lastAudioSeq = nil
            note("Microphone on. The band's light is solid blue.")
        } else if !on, micOn {
            note("Microphone off.")
        }
        micOn = on
    }

    // MARK: commands: one at a time, each waits for its response (2 s)

    public func command(_ opcode: Opcode, _ args: Data = Data()) async throws -> Response {
        let before = tail
        let work = Task { @MainActor () throws -> Response in
            await before?.value
            return try await self.exchange(opcode, args)
        }
        tail = Task { _ = try? await work.value }
        return try await work.value
    }

    private func exchange(_ opcode: Opcode, _ args: Data) async throws -> Response {
        guard let link else { throw BandError(code: "not-connected", message: "The band is not connected.") }
        seq &+= 1
        let mine = seq
        let response: Response = try await withCheckedThrowingContinuation { done in
            pending = (mine, opcode.rawValue, done)
            link.send(Command.frame(seq: mine, opcode: opcode.rawValue, args: args))
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, let waiting = self.pending, waiting.seq == mine else { return }
                self.pending = nil
                waiting.done.resume(throwing: BandError(code: "timeout", message: "The band did not answer in 2 seconds."))
            }
        }
        guard response.isOK else { throw Self.refusal(opcode, response.status) }
        return response
    }

    private static func refusal(_ opcode: Opcode, _ status: UInt8) -> BandError {
        switch Status(rawValue: status) {
        case .denied where opcode == .identify || opcode == .ledSet:
            return BandError(code: "denied", message: "The band refused: its light is locked while the microphone is on.")
        case .denied: return BandError(code: "denied", message: "The band refused (a safety rule).")
        case .busy: return BandError(code: "busy", message: "The band is busy. Try again in a moment.")
        case .notAvailable: return BandError(code: "not-available", message: "That part of this band is not working.")
        default: return BandError(code: "status-\(status)", message: "The band answered with error \(status).")
        }
    }

    // MARK: frames from the band

    private func receive(_ data: Data) {
        guard let frame = try? Codec.decode(data) else { return }      // not what the contract describes: skip it
        switch frame {
        case .response(let response):
            guard let waiting = pending, waiting.seq == response.seq, waiting.opcode == response.opcode else { return }
            pending = nil
            waiting.done.resume(returning: response)
        case .notice(let notice):
            switch notice.code {
            case Notice.lowBattery: note("Band battery low (\(notice.arg)%).")
            case Notice.criticalBattery: note("Band battery critical (\(notice.arg)%). Streams stopped: charge it."); markMic(false)
            case Notice.streamDropped where notice.arg == 3: note("Some sound was lost (weak link).")
            default: break
            }
        case .stream(let stream):
            switch stream {
            case .audio(let seq, let opus):
                if let last = lastAudioSeq {
                    let gap = Int(seq &- last) - 1
                    if gap > 0, gap < 30_000 { audioLost += gap }
                }
                lastAudioSeq = seq
                audioPackets += 1
                audioBytes += opus.count
                onAudio?(seq, opus)
            case .battery(let reading):
                battery = reading
            case .link(_, let value, _, _):
                rssi = value == 127 ? nil : Int(value)
            case .event(_, let event, _):
                guard let gesture = BandGesture(rawValue: event) else { return }
                onGesture?(gesture)
                switch gesture {
                case .tap: note("Tap")
                case .doubleTap: note("Double-tap")
                case .freeFall: note("Free-fall")
                default: break
                }
            default:
                break
            }
        case .unknown:
            break
        }
    }

    private func note(_ text: String) {
        log.insert(BandLogEntry(time: Date(), text: text), at: 0)
        if log.count > 40 { log.removeLast(log.count - 40) }
    }
}
