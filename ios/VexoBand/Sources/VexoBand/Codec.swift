// The Vexo Open band contract v1.1, byte by byte (vexo-open-kit/contract/contract.md).
// Pure Swift, no Bluetooth: everything here is checked against the kit's shared test vectors.
import Foundation

public enum VexoContract {
    public static let serviceUUID = "254f0001-df82-4a9c-a2b5-563a0f6b2021"
    public static let rxUUID = "254f0002-df82-4a9c-a2b5-563a0f6b2021"   // phone -> band
    public static let txUUID = "254f0003-df82-4a9c-a2b5-563a0f6b2021"   // band -> phone (notify)
    public static let namePrefix = "Vexo-HACK-"

    /// Band 7 is "Vexo-HACK-07", band 123 is "Vexo-HACK-123".
    public static func name(forBand number: Int) -> String {
        number < 100 ? namePrefix + String(format: "%02d", number) : namePrefix + String(number)
    }

    /// The band number in the advertising packet's manufacturer data, as CoreBluetooth
    /// hands it over: company id 0xFFFF (2 bytes), then 0x4F, proto_major, band_no u16.
    public static func bandNumber(fromManufacturerData data: Data) -> Int? {
        let b = [UInt8](data)
        guard b.count >= 6, b[0] == 0xFF, b[1] == 0xFF, b[2] == 0x4F else { return nil }
        return Int(b[4]) | Int(b[5]) << 8
    }
}

// SET_BAND_NUMBER (0x03) is left out on purpose: only the organisers renumber a band.
public enum Opcode: UInt8, CaseIterable, Sendable {
    case getInfo = 0x01, getName = 0x02, identify = 0x04, restart = 0x05, sleep = 0x06
    case timeSet = 0x07, timeGet = 0x08
    case streamStart = 0x10, streamStop = 0x11, streamGet = 0x12
    case streamSetInterval = 0x13, streamGetInterval = 0x14
    case imuSet = 0x20, imuGet = 0x21, eventSet = 0x22, eventGet = 0x23
    case motion2Set = 0x24, motion2Get = 0x25
    case micSetGain = 0x30, micGet = 0x31
    case radioSetTxPower = 0x40, radioGet = 0x41
    case ledSet = 0x50, ledGet = 0x51
    case tempSetInterval = 0x60, batteryGet = 0x61
    case storeInfo = 0x70, storePut = 0x71, storeGet = 0x72, storeDel = 0x73, storeWipe = 0x74

    /// How many data bytes an OK response carries (contract section 3).
    var okLength: ClosedRange<Int> {
        switch self {
        case .getInfo: return 16...16
        case .getName: return 12...13
        case .timeSet, .timeGet, .streamSetInterval, .streamGetInterval: return 13...13
        case .streamStart, .streamStop, .streamGet: return 2...2
        case .imuSet, .imuGet: return 4...4
        case .eventSet, .eventGet: return 3...3
        case .motion2Set, .motion2Get: return 9...9
        case .micSetGain, .radioSetTxPower, .tempSetInterval: return 1...1
        case .micGet, .radioGet, .ledGet: return 7...7
        case .batteryGet: return 4...4
        case .storeInfo: return 10...10
        case .storeGet: return 1...232
        case .identify, .restart, .sleep, .ledSet, .storePut, .storeDel, .storeWipe: return 0...0
        }
    }
}

public enum Status: UInt8, Sendable {
    case ok = 0, unknownOpcode, badLength, badArg, busy, notAvailable, denied, notFound, noSpace, ioError
}

/// Bits for STREAM_START / STREAM_STOP. Bit n starts frame type 0x10 + n.
public struct StreamMask: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16
    public init(rawValue: UInt16) { self.rawValue = rawValue }
    public static let motion = StreamMask(rawValue: 1 << 0)
    public static let event = StreamMask(rawValue: 1 << 1)
    public static let activity = StreamMask(rawValue: 1 << 2)
    public static let audio = StreamMask(rawValue: 1 << 3)
    public static let battery = StreamMask(rawValue: 1 << 4)
    public static let temp = StreamMask(rawValue: 1 << 5)
    public static let link = StreamMask(rawValue: 1 << 6)
    public static let micLevel = StreamMask(rawValue: 1 << 7)
    public static let motion2 = StreamMask(rawValue: 1 << 8)
    public static let all = StreamMask(rawValue: 0xFFFF)
}

// MARK: - What the band sends

public struct Response: Equatable, Sendable {
    public let seq: UInt8
    public let opcode: UInt8
    public let status: UInt8
    public let data: Data
    public var isOK: Bool { status == 0 }
}

public struct Notice: Equatable, Sendable {
    public static let lowBattery: UInt8 = 1, criticalBattery: UInt8 = 2, streamDropped: UInt8 = 3, usbPower: UInt8 = 4
    public let code: UInt8
    public let arg: UInt8
}

public struct MotionSample: Equatable, Sendable {
    /// milli-g; nil when the accelerometer was left out (MOTION2, gyro only)
    public var ax, ay, az: Int16?
    /// tenths of a degree per second; nil when the gyroscope was left out
    public var gx, gy, gz: Int16?
}

public struct BatteryReading: Equatable, Sendable {
    public let percent: Int
    /// 0 on battery, 1 charging, 2 charged
    public let state: Int
    public let millivolts: Int
}

public enum BandGesture: UInt8, Sendable {
    case tap = 1, doubleTap, freeFall, tilt, orientation, motionStart, motionStop
}

public enum StreamFrame: Equatable, Sendable {
    case motion(tMs: UInt32, periodMs: UInt8, samples: [MotionSample])
    case event(tMs: UInt32, event: UInt8, arg: UInt8)
    case activity(tMs: UInt32, stepsTotal: UInt32, cadence: UInt8, state: UInt8, motionMg: UInt16)
    case audio(seq: UInt16, opus: Data)
    case battery(BatteryReading)
    case temp(tMs: UInt32, milliC: Int32)
    case link(tMs: UInt32, rssi: Int8, txDbm: Int8, phy: UInt8)
    case micLevel(tMs: UInt32, peakDb: UInt8, rmsDb: UInt8)
    case motion2(tMs: UInt32, sampleNo: UInt32, periodUs: UInt32, sensors: UInt8, samples: [MotionSample])
}

public enum Frame: Equatable, Sendable {
    case response(Response)
    case notice(Notice)
    case stream(StreamFrame)
    /// A frame type this client does not know: ignore it, it is not an error.
    case unknown(type: UInt8)
}

public struct FrameError: Error, Equatable {
    public let reason: String
}

public struct BandInfo: Equatable, Sendable {
    public let protoMajor, protoMinor: Int
    public let firmware: String
    public let hardware: Int
    public let bandNumber: Int
    public let caps: UInt16
    public let maxFrame: Int
    public let uptimeMs: UInt32

    public init(data: Data) throws {
        var r = Reader(data)
        protoMajor = Int(try r.u8()); protoMinor = Int(try r.u8())
        let major = try r.u8(), minor = try r.u8(), patch = try r.u8()
        firmware = "\(major).\(minor).\(patch)"
        hardware = Int(try r.u8())
        bandNumber = Int(try r.u16())
        caps = try r.u16()
        maxFrame = Int(try r.u16())
        uptimeMs = try r.u32()
    }
}

public extension BatteryReading {
    init(data: Data) throws {
        var r = Reader(data)
        percent = Int(try r.u8()); state = Int(try r.u8()); millivolts = Int(try r.u16())
    }
}

// MARK: - Reading and writing bytes (little-endian, packed)

struct Reader {
    private let bytes: [UInt8]
    private var at = 0
    init(_ data: Data) { bytes = [UInt8](data) }
    var left: Int { bytes.count - at }

    mutating func take(_ count: Int) throws -> [UInt8] {
        guard count >= 0, left >= count else { throw FrameError(reason: "cut short") }
        defer { at += count }
        return Array(bytes[at..<at + count])
    }
    mutating func u8() throws -> UInt8 { try take(1)[0] }
    mutating func i8() throws -> Int8 { Int8(bitPattern: try u8()) }
    mutating func u16() throws -> UInt16 { let b = try take(2); return UInt16(b[0]) | UInt16(b[1]) << 8 }
    mutating func i16() throws -> Int16 { Int16(bitPattern: try u16()) }
    mutating func u32() throws -> UInt32 {
        let b = try take(4)
        return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
    }
    mutating func i32() throws -> Int32 { Int32(bitPattern: try u32()) }
    mutating func rest() -> Data { defer { at = bytes.count }; return Data(bytes[at...]) }
}

public extension Data {
    mutating func appendLE(_ value: UInt16) { append(UInt8(value & 0xFF)); append(UInt8(value >> 8)) }
    mutating func appendLE(_ value: UInt32) { for shift in stride(from: 0, to: 32, by: 8) { append(UInt8((value >> UInt32(shift)) & 0xFF)) } }
    mutating func appendLE(_ value: UInt64) { for shift in stride(from: 0, to: 64, by: 8) { append(UInt8((value >> UInt64(shift)) & 0xFF)) } }
}

// MARK: - Commands (phone -> band)

public enum Command {
    /// A command frame: [0x01][seq][opcode][args].
    public static func frame(seq: UInt8, opcode: UInt8, args: Data = Data()) -> Data {
        var d = Data([0x01, seq, opcode])
        d.append(args)
        return d
    }

    public static func streamMask(_ mask: StreamMask) -> Data { var d = Data(); d.appendLE(mask.rawValue); return d }
    public static func timeSet(unixMs: UInt64) -> Data { var d = Data(); d.appendLE(unixMs); return d }
    public static func identify(seconds: UInt8) -> Data { Data([seconds]) }
    public static func micGain(halfDb: UInt8) -> Data { Data([halfDb]) }
    public static func led(r: UInt8, g: UInt8, b: UInt8, brightness: UInt8, pattern: UInt8, periodMs: UInt16) -> Data {
        var d = Data([r, g, b, brightness, pattern]); d.appendLE(periodMs); return d
    }
    public static func streamInterval(stream: UInt8, intervalMs: UInt32) -> Data {
        var d = Data([stream]); d.appendLE(intervalMs); return d
    }
}

// MARK: - Decoding (band -> phone)

public enum Codec {
    /// One frame from the band. Throws FrameError for a frame that is cut short or does
    /// not fit the contract: the caller ignores it and keeps waiting.
    public static func decode(_ frame: Data) throws -> Frame {
        var r = Reader(frame)
        let type = try r.u8()
        switch type {
        case 0x01:
            throw FrameError(reason: "a command is never sent by the band")
        case 0x02:
            let seq = try r.u8(), opcode = try r.u8(), status = try r.u8()
            let data = r.rest()
            if let known = Opcode(rawValue: opcode) {
                if status == 0, !known.okLength.contains(data.count) { throw FrameError(reason: "wrong response length") }
                if status != 0, !data.isEmpty { throw FrameError(reason: "an error response carries no data") }
            }
            return .response(Response(seq: seq, opcode: opcode, status: status, data: data))
        case 0x03:
            return .notice(Notice(code: try r.u8(), arg: try r.u8()))
        case 0x10:
            let t = try r.u32(), period = try r.u8(), count = Int(try r.u8())
            return .stream(.motion(tMs: t, periodMs: period, samples: try samples(&r, count: count, sensors: 3)))
        case 0x11:
            return .stream(.event(tMs: try r.u32(), event: try r.u8(), arg: try r.u8()))
        case 0x12:
            return .stream(.activity(tMs: try r.u32(), stepsTotal: try r.u32(), cadence: try r.u8(), state: try r.u8(), motionMg: try r.u16()))
        case 0x13:
            let seq = try r.u16(), len = Int(try r.u8())
            return .stream(.audio(seq: seq, opus: Data(try r.take(len))))
        case 0x14:
            return .stream(.battery(BatteryReading(percent: Int(try r.u8()), state: Int(try r.u8()), millivolts: Int(try r.u16()))))
        case 0x15:
            return .stream(.temp(tMs: try r.u32(), milliC: try r.i32()))
        case 0x16:
            return .stream(.link(tMs: try r.u32(), rssi: try r.i8(), txDbm: try r.i8(), phy: try r.u8()))
        case 0x17:
            return .stream(.micLevel(tMs: try r.u32(), peakDb: try r.u8(), rmsDb: try r.u8()))
        case 0x18:
            let t = try r.u32(), no = try r.u32(), period = try r.u32(), sensors = try r.u8(), count = Int(try r.u8())
            guard (1...3).contains(sensors) else { throw FrameError(reason: "unknown sensors value") }
            return .stream(.motion2(tMs: t, sampleNo: no, periodUs: period, sensors: sensors,
                                    samples: try samples(&r, count: count, sensors: sensors)))
        default:
            return .unknown(type: type)
        }
    }

    private static func samples(_ r: inout Reader, count: Int, sensors: UInt8) throws -> [MotionSample] {
        var out: [MotionSample] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            var s = MotionSample()
            if sensors & 1 != 0 { s.ax = try r.i16(); s.ay = try r.i16(); s.az = try r.i16() }
            if sensors & 2 != 0 { s.gx = try r.i16(); s.gy = try r.i16(); s.gz = try r.i16() }
            out.append(s)
        }
        return out
    }
}
