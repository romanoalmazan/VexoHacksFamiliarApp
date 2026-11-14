// Checks the Swift codec against the kit's shared test vectors
// (a copy of vexo-open-kit/contract/test-vectors.json).
import XCTest
@testable import VexoBand

final class CodecTests: XCTestCase {
    private var vectors: [String: Any] = [:]

    override func setUpWithError() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "test-vectors", withExtension: "json"))
        vectors = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func list(_ key: String) -> [[String: Any]] { vectors[key] as? [[String: Any]] ?? [] }

    private func bytes(_ hex: String) -> Data {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return data
    }

    private func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

    func testNames() {
        for item in list("names") {
            XCTAssertEqual(VexoContract.name(forBand: item["number"] as! Int), item["name"] as! String)
        }
        XCTAssertEqual(VexoContract.name(forBand: 64), "Vexo-HACK-64")
    }

    func testManufacturerData() {
        XCTAssertEqual(VexoContract.bandNumber(fromManufacturerData: Data([0xFF, 0xFF, 0x4F, 0x01, 0x40, 0x00])), 64)
        XCTAssertEqual(VexoContract.bandNumber(fromManufacturerData: Data([0xFF, 0xFF, 0x4F, 0x01, 0xE7, 0x03])), 999)
        XCTAssertNil(VexoContract.bandNumber(fromManufacturerData: Data([0x4C, 0x00, 0x4F, 0x01, 0x40, 0x00])))
        XCTAssertNil(VexoContract.bandNumber(fromManufacturerData: Data([0xFF, 0xFF, 0x4F])))
    }

    func testOpcodeNumbers() {
        let table = vectors["opcodes"] as! [String: Int]
        let ours = Set(Opcode.allCases.map { Int($0.rawValue) })
        let theirs = Set(table.filter { $0.key != "SET_BAND_NUMBER" }.values)
        XCTAssertEqual(ours, theirs)
    }

    func testCommandsEncode() throws {
        let opcodes = vectors["opcodes"] as! [String: Int]
        var checked = 0
        for item in list("commands") {
            let name = item["name"] as! String
            let args = item["args"] as! [String: Any]
            func int(_ key: String) -> Int { args[key] as! Int }
            var body = Data()
            switch name {
            case "SET_BAND_NUMBER": continue            // not in this client, on purpose
            case "STORE_WIPE": continue                 // carries a fixed magic; this app never wipes
            case "STREAM_START", "STREAM_STOP": body = Command.streamMask(StreamMask(rawValue: UInt16(int("mask"))))
            case "IDENTIFY": body = Command.identify(seconds: UInt8(int("seconds")))
            case "TIME_SET": body = Command.timeSet(unixMs: UInt64(int("unix_ms")))
            case "MIC_SET_GAIN": body = Command.micGain(halfDb: UInt8(int("gain_half_db")))
            case "LED_SET":
                body = Command.led(r: UInt8(int("r")), g: UInt8(int("g")), b: UInt8(int("b")), brightness: UInt8(int("brightness")),
                                   pattern: UInt8(int("pattern")), periodMs: UInt16(int("period_ms")))
            case "STREAM_SET_INTERVAL": body = Command.streamInterval(stream: UInt8(int("stream")), intervalMs: UInt32(int("interval_ms")))
            default:
                guard args.isEmpty else { continue }    // commands with arguments this app does not send yet
            }
            let frame = Command.frame(seq: UInt8(item["seq"] as! Int), opcode: UInt8(opcodes[name]!), args: body)
            XCTAssertEqual(hex(frame), item["hex"] as! String, name)
            checked += 1
        }
        XCTAssertGreaterThan(checked, 20)
    }

    func testResponsesDecode() throws {
        let opcodes = vectors["opcodes"] as! [String: Int]
        let statuses = vectors["statuses"] as! [String]
        for item in list("responses") {
            let value = item["value"] as! [String: Any]
            guard case .response(let response) = try Codec.decode(bytes(item["hex"] as! String)) else {
                return XCTFail("not a response: \(item)")
            }
            XCTAssertEqual(Int(response.seq), value["seq"] as! Int)
            let opcode = (value["opcode"] as? Int) ?? opcodes[value["opcode"] as! String]!
            XCTAssertEqual(Int(response.opcode), opcode)
            let status = (value["status"] as? Int) ?? statuses.firstIndex(of: value["status"] as! String)!
            XCTAssertEqual(Int(response.status), status)

            let data = value["data"] as! [String: Any]
            if response.opcode == Opcode.getInfo.rawValue, response.isOK {
                let info = try BandInfo(data: response.data)
                XCTAssertEqual(info.bandNumber, data["band_no"] as! Int)
                XCTAssertEqual(info.maxFrame, data["max_frame"] as! Int)
                XCTAssertEqual(info.firmware, "\(data["fw_major"]!).\(data["fw_minor"]!).\(data["fw_patch"]!)")
                XCTAssertEqual(Int(info.uptimeMs), data["uptime_ms"] as! Int)
                XCTAssertEqual(Int(info.caps), data["caps"] as! Int)
            }
            if response.opcode == Opcode.batteryGet.rawValue, response.isOK {
                let battery = try BatteryReading(data: response.data)
                XCTAssertEqual(battery.percent, data["percent"] as! Int)
                XCTAssertEqual(battery.state, data["state"] as! Int)
                XCTAssertEqual(battery.millivolts, data["millivolts"] as! Int)
            }
            if response.opcode == Opcode.getName.rawValue, response.isOK {
                XCTAssertEqual(String(data: response.data, encoding: .ascii), data["name"] as? String)
            }
        }
    }

    func testNoticesDecode() throws {
        let names = ["LOW_BATTERY": 1, "CRITICAL_BATTERY": 2, "STREAM_DROPPED": 3, "USB_POWER": 4]
        for item in list("notices") {
            let value = item["value"] as! [String: Any]
            guard case .notice(let notice) = try Codec.decode(bytes(item["hex"] as! String)) else { return XCTFail("\(item)") }
            let code = (value["code"] as? Int) ?? names[value["code"] as! String]!
            XCTAssertEqual(Int(notice.code), code)
            XCTAssertEqual(Int(notice.arg), value["arg"] as! Int)
        }
    }

    func testStreamsDecode() throws {
        var kinds = Set<String>()
        for item in list("streams") {
            let value = item["value"] as! [String: Any]
            let kind = value["frame"] as! String
            kinds.insert(kind)
            func int(_ key: String) -> Int { value[key] as! Int }
            let frame = try Codec.decode(bytes(item["hex"] as! String))
            if kind == "unknown" {
                XCTAssertEqual(frame, .unknown(type: UInt8(int("type"))))
                continue
            }
            guard case .stream(let stream) = frame else { return XCTFail("\(item)") }
            switch stream {
            case .motion(let t, let period, let samples):
                XCTAssertEqual(kind, "motion")
                XCTAssertEqual(Int(t), int("t_ms")); XCTAssertEqual(Int(period), int("period_ms"))
                check(samples, value["samples"] as! [[String: Int]])
            case .motion2(let t, let no, let period, let sensors, let samples):
                XCTAssertEqual(kind, "motion2")
                XCTAssertEqual(Int(t), int("t_ms")); XCTAssertEqual(Int(no), int("sample_no"))
                XCTAssertEqual(Int(period), int("period_us")); XCTAssertEqual(Int(sensors), int("sensors"))
                check(samples, value["samples"] as! [[String: Int]])
            case .event(let t, let event, let arg):
                XCTAssertEqual(kind, "event")
                XCTAssertEqual(Int(t), int("t_ms")); XCTAssertEqual(Int(event), int("event")); XCTAssertEqual(Int(arg), int("arg"))
            case .activity(let t, let steps, let cadence, let state, let motion):
                XCTAssertEqual(kind, "activity")
                XCTAssertEqual(Int(t), int("t_ms")); XCTAssertEqual(Int(steps), int("steps_total"))
                XCTAssertEqual(Int(cadence), int("cadence_spm")); XCTAssertEqual(Int(state), int("state")); XCTAssertEqual(Int(motion), int("motion_mg"))
            case .audio(let seq, let opus):
                XCTAssertEqual(kind, "audio")
                XCTAssertEqual(Int(seq), int("seq")); XCTAssertEqual(hex(opus), value["opus"] as! String)
            case .battery(let battery):
                XCTAssertEqual(kind, "battery")
                XCTAssertEqual(battery.percent, int("percent")); XCTAssertEqual(battery.state, int("state")); XCTAssertEqual(battery.millivolts, int("millivolts"))
            case .temp(let t, let milliC):
                XCTAssertEqual(kind, "temp")
                XCTAssertEqual(Int(t), int("t_ms")); XCTAssertEqual(Int(milliC), int("temp_mc"))
            case .link(let t, let rssi, let tx, let phy):
                XCTAssertEqual(kind, "link")
                XCTAssertEqual(Int(t), int("t_ms")); XCTAssertEqual(Int(rssi), int("rssi_dbm")); XCTAssertEqual(Int(tx), int("tx_dbm")); XCTAssertEqual(Int(phy), int("phy"))
            case .micLevel(let t, let peak, let rms):
                XCTAssertEqual(kind, "mic_level")
                XCTAssertEqual(Int(t), int("t_ms")); XCTAssertEqual(Int(peak), int("peak_db")); XCTAssertEqual(Int(rms), int("rms_db"))
            }
        }
        XCTAssertEqual(kinds, ["motion", "event", "activity", "audio", "battery", "temp", "link", "mic_level", "motion2", "unknown"])
    }

    private func check(_ samples: [MotionSample], _ expected: [[String: Int]], line: UInt = #line) {
        XCTAssertEqual(samples.count, expected.count, line: line)
        for (sample, want) in zip(samples, expected) {
            XCTAssertEqual(sample.ax.map(Int.init), want["ax"], line: line); XCTAssertEqual(sample.ay.map(Int.init), want["ay"], line: line)
            XCTAssertEqual(sample.az.map(Int.init), want["az"], line: line); XCTAssertEqual(sample.gx.map(Int.init), want["gx"], line: line)
            XCTAssertEqual(sample.gy.map(Int.init), want["gy"], line: line); XCTAssertEqual(sample.gz.map(Int.init), want["gz"], line: line)
        }
    }

    func testInvalidFramesAreRejected() {
        for item in list("invalid") {
            XCTAssertThrowsError(try Codec.decode(bytes(item["hex"] as! String)), item["note"] as? String ?? "")
        }
        XCTAssertEqual(list("invalid").count, 15)
    }
}
