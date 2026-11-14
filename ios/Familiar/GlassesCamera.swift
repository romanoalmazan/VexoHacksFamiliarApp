import Foundation
import MWDATCamera
import MWDATCore
import MWDATMockDevice
import Observation
import UIKit

/// The Meta glasses' camera, through Meta's Wearables Device Access Toolkit. It gives the
/// app the same thing the iPhone camera does: about one JPEG a second.
///
/// Before the first use, on the phone: pair the glasses in the Meta AI app, turn on
/// Developer Mode there (Settings → Your glasses → Developer Mode), then tap "Link Meta
/// glasses" in Familiar. Meta AI opens, asks, and sends you back.
@MainActor
@Observable
final class GlassesCamera {
    enum Status: Equatable {
        case off
        case starting
        case waiting            // linked and started, but no picture yet (glasses folded or not worn?)
        case streaming
        case paused             // the glasses paused it (a tap on the temple, or another app)
        case problem(String)
    }

    private(set) var status: Status = .off
    /// Whether Meta AI has approved this app for the glasses.
    private(set) var isLinked = false
    private(set) var isLinking = false
    private(set) var isPretend = false
    /// What the glasses see, for the screen.
    private(set) var preview: UIImage?
    /// The newest picture, for enrolling the face in view.
    private(set) var latestJPEG: Data?
    /// Called about once a second with a JPEG.
    @ObservationIgnored var onFrame: ((Data) -> Void)?

    @ObservationIgnored private var session: DeviceSession?
    @ObservationIgnored private var camera: Camera?
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var errors: Task<Void, Never>?
    @ObservationIgnored private let tokens = ListenerTokenBag()
    @ObservationIgnored private static var configured = false

    static let secondsBetweenPictures: TimeInterval = 1

    /// Once, at launch.
    static func configure() {
        guard !configured else { return }
        do {
            try Wearables.configure()
            configured = true
        } catch {
            print("Meta glasses toolkit did not start: \(error)")
        }
    }

    /// Keeps `isLinked` true to the toolkit's own state. Runs for the life of the app.
    func watch() async {
        guard Self.configured else { return }
        for await state in Wearables.shared.registrationStateStream() {
            isLinked = state == .registered
            isLinking = state == .registering
        }
    }

    /// Opens the Meta AI app to approve Familiar. It comes back through `handle(_:)`.
    func link() async {
        guard Self.configured else {
            status = .problem("The Meta glasses toolkit did not start on this device.")
            return
        }
        do {
            try await Wearables.shared.startRegistration()
        } catch {
            status = .problem("Could not link the glasses: \(error.localizedDescription) Is the Meta AI app installed, with Developer Mode on?")
        }
    }

    /// A link Meta AI opened the app with.
    func handle(_ url: URL) {
        guard Self.configured,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true else { return }
        Task {
            do {
                _ = try await Wearables.shared.handleUrl(url)
            } catch {
                status = .problem("Meta AI could not finish linking: \(error.localizedDescription)")
            }
        }
    }

    /// Pretend glasses from Meta's toolkit, for the Simulator or a day without the real
    /// ones. They show a video file, or with no file the iPhone's own back camera.
    func usePretend(video: URL? = nil) {
        guard Self.configured, !isPretend else { return }
        do {
            MockDeviceKit.shared.enable()
            let glasses = try MockDeviceKit.shared.pairGlasses(model: .rayBanMeta)
            glasses.powerOn()
            glasses.unfold()
            glasses.don()
            if let video {
                glasses.services.camera.setCameraFeed(fileURL: video)
            } else {
                glasses.services.camera.setCameraFeed(cameraFacing: .back)
            }
            isPretend = true
        } catch {
            status = .problem("Could not make pretend glasses: \(error.localizedDescription)")
        }
    }

    func start() {
        guard running == nil else { return }
        guard Self.configured else {
            status = .problem("The Meta glasses toolkit did not start on this device.")
            return
        }
        status = .starting
        running = Task { [weak self] in
            await self?.run()
            self?.running = nil
        }
    }

    func stop() {
        camera?.stop()
        session?.stop()
        running?.cancel()
        running = nil
        release()
        status = .off
    }

    private func release() {
        tokens.clear()
        errors?.cancel()
        errors = nil
        camera = nil
        session = nil
        preview = nil
        latestJPEG = nil
    }

    private func run() async {
        let wearables = Wearables.shared
        do {
            // The toolkit needs a moment to find glasses that are on, unfolded and connected.
            // Starting before it has one fails at once, so wait for it (as Meta's sample does).
            let selector = AutoDeviceSelector(wearables: wearables)
            status = .waiting
            for _ in 0..<60 where selector.activeDevice == nil && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            if Task.isCancelled { return }
            guard selector.activeDevice != nil else {
                status = .problem(Self.sentence(for: .noEligibleDevice))
                return
            }
            status = .starting
            if try await wearables.checkPermissionStatus(.camera) != .granted {
                // Opens Meta AI to ask. The user tapped "Look for faces", so it is expected.
                guard try await wearables.requestPermission(.camera) == .granted else {
                    status = .problem("Meta AI did not allow Familiar to use the glasses' camera.")
                    return
                }
            }
            let session = try wearables.createSession(deviceSelector: selector)
            self.session = session
            let states = session.stateStream()
            let problems = session.errorStream()
            errors = Task { [weak self] in
                for await problem in problems {
                    print("Glasses session problem:", problem, Self.facts())
                    self?.status = .problem(Self.sentence(for: problem))
                }
            }
            try session.start()
            for await state in states {
                if Task.isCancelled { return }
                switch state {
                case .started:
                    if camera == nil { try attach(to: session) } else { status = .streaming }
                case .paused:
                    status = .paused
                case .stopped:
                    release()
                    if case .problem = status { return }
                    status = .off
                    return
                default:
                    break
                }
            }
        } catch {
            release()
            print("Glasses could not start:", error, Self.facts())
            status = .problem((error as? DeviceSessionError).map(Self.sentence) ?? "\(error.localizedDescription) (\(error)). \(Self.facts())")
        }
    }

    private func attach(to session: DeviceSession) throws {
        // A low frame rate leaves more of the Bluetooth link for each picture, and one
        // picture a second is all the server is sent.
        let settings = StreamConfiguration(videoCodec: .raw, resolution: .medium, frameRate: 7)
        guard let camera = try session.addCamera(config: settings) else {
            status = .problem("The glasses were not ready for the camera. Try again.")
            return
        }
        self.camera = camera
        let stream = camera.stream
        let gate = Gate(every: Self.secondsBetweenPictures)

        stream.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                guard let self, self.camera != nil else { return }
                switch state {
                case .streaming: self.status = .streaming
                case .paused: self.status = .paused
                case .waitingForDevice, .starting: self.status = .waiting
                default: break
                }
            }
        }.store(in: tokens)

        stream.videoFramePublisher.listen { [weak self] frame in
            guard let image = frame.makeUIImage() else { return }
            let jpeg = gate.open() ? image.jpegData(compressionQuality: 0.7) : nil
            Task { @MainActor in
                guard let self, self.camera != nil else { return }
                self.preview = image
                if let jpeg {
                    self.latestJPEG = jpeg
                    self.onFrame?(jpeg)
                }
            }
        }.store(in: tokens)

        stream.errorPublisher.listen { [weak self] problem in
            Task { @MainActor in
                print("Glasses camera problem:", problem, Self.facts())
                self?.status = .problem("\(problem.localizedDescription) \(Self.facts())")
            }
        }.store(in: tokens)

        status = .waiting
        stream.start()
    }

    private static func sentence(for problem: DeviceSessionError) -> String {
        switch problem {
        case .noEligibleDevice:
            return "No glasses found. Put them on, unfolded, with Bluetooth on, and check they are connected in the Meta AI app."
        case .datAppOnTheGlassesUpdateRequired:
            return "The glasses need an update. Open the Meta AI app and update them."
        case .batteryCritical:
            return "The glasses' battery is too low for the camera."
        case .thermalCritical, .thermalEmergency:
            return "The glasses are too hot for the camera. Let them cool down."
        default:
            // Seen on real glasses: they refuse to start ("Device unavailable") while not worn.
            let wearables = Wearables.shared
            let worn = wearables.devices.compactMap { wearables.deviceForIdentifier($0) }.contains { $0.donState == .donned }
            if !worn { return "Put the glasses on. Their camera only starts while they are being worn. Then switch this off and on again." }
            return "\(problem.localizedDescription) (\(problem)). \(facts())"
        }
    }

    /// What the toolkit knows about the glasses right now, to make a problem easier to fix.
    private static func facts() -> String {
        let wearables = Wearables.shared
        let known = wearables.devices.compactMap { wearables.deviceForIdentifier($0) }
        guard !known.isEmpty else { return "The toolkit sees no glasses." }
        return known.map { glasses in
            "\(glasses.nameOrId()): link \(glasses.linkState), \(glasses.donState), hinges \(glasses.hingeState), software \(glasses.compatibility())"
                + (glasses.batteryLevel.map { ", battery \($0)%" } ?? "")
        }.joined(separator: "; ")
    }
}

/// Lets one thing through every so often. Used from the toolkit's own thread.
private final class Gate: @unchecked Sendable {
    private let every: TimeInterval
    private var last = Date.distantPast
    private let lock = NSLock()

    init(every: TimeInterval) { self.every = every }

    func open() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard Date().timeIntervalSince(last) >= every else { return false }
        last = Date()
        return true
    }
}
