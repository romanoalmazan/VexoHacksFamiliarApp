// A pretend band that speaks the real contract, so the app runs in the Simulator (which
// has no Bluetooth) and with no hardware. It taps itself every 4 seconds, reports a
// battery, and "streams" made-up audio packets (not real sound) when the mic is on.
import Foundation

@MainActor
public final class SimLink: BandLink {
    public var onEvent: ((LinkEvent) -> Void)?
    public var onFrame: ((Data) -> Void)?

    private let band: Int
    private var active: StreamMask = []
    private var runner: Task<Void, Never>?
    private var started = Date()
    private var audioSeq: UInt16 = 0

    public init(band: Int) { self.band = band }

    public func open(searchSeconds: TimeInterval) {
        onEvent?(.searching)
        runner?.cancel()
        runner = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self, !Task.isCancelled else { return }
            self.onEvent?(.connecting)
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self.started = Date()
            self.active = []
            self.onEvent?(.ready)
            await self.run()
        }
    }

    public func close() {
        runner?.cancel()
        runner = nil
        active = []
        onEvent?(.closed(byUs: true))
    }

    private var uptime: UInt32 { UInt32(Date().timeIntervalSince(started) * 1000) + 60_000 }

    private func emit(_ type: UInt8, _ build: (inout Data) -> Void) {
        var d = Data([type])
        build(&d)
        onFrame?(d)
    }

    /// 10 ticks a second: audio in bursts of 5 packets, a tap every 4 s, signal once a second.
    private func run() async {
        var tick = 0
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            tick += 1
            if active.contains(.audio) {
                for _ in 0..<5 {
                    emit(0x13) { d in
                        d.appendLE(audioSeq)
                        d.append(40)
                        d.append(Data(repeating: 0, count: 40))
                    }
                    audioSeq &+= 1
                }
            }
            if active.contains(.link), tick % 10 == 0 {
                emit(0x16) { d in
                    d.appendLE(uptime)
                    d.append(UInt8(bitPattern: Int8(-55 + Int.random(in: -3...3))))
                    d.append(UInt8(bitPattern: -8))
                    d.append(2)
                }
            }
            if active.contains(.event), tick % 40 == 0 {
                let double = (tick / 40) % 2 == 0
                emit(0x11) { d in d.appendLE(uptime); d.append(double ? 2 : 1); d.append(0) }
            }
        }
    }

    private func batteryBody() -> Data { var d = Data([87, 0]); d.appendLE(UInt16(3987)); return d }

    public func send(_ frame: Data) {
        let b = [UInt8](frame)
        guard b.count >= 3, b[0] == 0x01 else { return }
        let seq = b[1], opcode = b[2], args = Array(b[3...])
        var status: UInt8 = 0
        var data = Data()
        let micOn = active.contains(.audio) || active.contains(.micLevel)

        switch Opcode(rawValue: opcode) {
        case .getInfo:
            data = Data([1, 1, 1, 1, 0, 1])
            data.appendLE(UInt16(band)); data.appendLE(UInt16(0x07FF)); data.appendLE(UInt16(244)); data.appendLE(uptime)
        case .getName:
            data = Data(VexoContract.name(forBand: band).utf8)
        case .timeSet where args.count == 8:
            data = Data([1]); data.append(contentsOf: args); data.appendLE(uptime)
        case .streamStart where args.count == 2, .streamStop where args.count == 2:
            let mask = StreamMask(rawValue: UInt16(args[0]) | UInt16(args[1]) << 8)
            if opcode == Opcode.streamStart.rawValue {
                if mask.contains(.audio), !active.contains(.audio) { audioSeq = 0 }
                active.formUnion(mask)
            } else {
                active.subtract(mask)
            }
            data.appendLE(active.rawValue)
            if opcode == Opcode.streamStart.rawValue, mask.contains(.battery) {
                let body = batteryBody()
                Task { [weak self] in self?.emit(0x14) { $0.append(body) } }
            }
        case .streamGet:
            data.appendLE(active.rawValue)
        case .batteryGet:
            data = batteryBody()
        case .micGet:
            data = Data([80]); data.appendLE(UInt16(16000)); data.append(20); data.append(1); data.appendLE(UInt16(24000))
        case .micSetGain where args.count == 1:
            data = Data([args[0]])
        case .identify, .ledSet:
            status = micOn ? Status.denied.rawValue : 0      // the mic indicator owns the light
        case .none:
            status = Status.unknownOpcode.rawValue
        default:
            status = Status.badLength.rawValue
        }

        var response = Data([0x02, seq, opcode, status])
        if status == 0 { response.append(data) }
        Task { [weak self] in self?.onFrame?(response) }
    }
}
