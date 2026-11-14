import SwiftUI
import VexoBand

enum BandConfig {
    /// The team's band number: the one on the band's bag. The only place it is written.
    /// The app never scans for, connects to, or commands any other band.
    static let teamBand = 64
}

@main
struct FamiliarApp: App {
    @State private var band = BandClient(band: BandConfig.teamBand)
    @State private var transcript = TranscriptClient()
    @State private var watch = FaceWatch(faces: FaceClient(), glasses: GlassesCamera())

    private var faces: FaceClient { watch.faces }
    private var glasses: GlassesCamera { watch.glasses }

    init() {
        GlassesCamera.configure()
    }

    var body: some Scene {
        WindowGroup {
            BandView(band: band, transcript: transcript, watch: watch)
                .onOpenURL { glasses.handle($0) }       // Meta AI coming back after linking
                .task { await glasses.watch() }
                .task {
                    // For automated checks only: launch with -demoGlasses <video file> to use
                    // the toolkit's pretend glasses, showing that video as their camera.
                    let arguments = ProcessInfo.processInfo.arguments
                    guard let at = arguments.firstIndex(of: "-demoGlasses"), arguments.count > at + 1 else { return }
                    glasses.usePretend(video: URL(fileURLWithPath: arguments[at + 1]))
                    // With -serverAddress and -pairingCode too, the pictures go to the server:
                    // the first one enrols "Demo check", the rest should recognise them.
                    let defaults = UserDefaults.standard
                    if let server = defaults.string(forKey: "serverAddress") {
                        faces.speaks = false
                        faces.start(server: server, code: defaults.string(forKey: "pairingCode") ?? "")
                    }
                    var enrolled = false
                    glasses.onFrame = { jpeg in
                        print("demoGlasses picture:", jpeg.count, "bytes")
                        guard faces.state == .live else { return }
                        if enrolled { faces.look(jpeg) } else { faces.enrol(name: "Demo check", relationship: "test", jpeg: jpeg); enrolled = true }
                    }
                    glasses.start()
                    for _ in 0..<8 {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        print("demoGlasses status:", glasses.status, "in view:", faces.inView.map { "\($0.name) \($0.match ?? "")" }, faces.notice ?? "")
                    }
                    faces.forget("Demo check")
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    glasses.stop()
                    faces.stop()
                }
                .task {
                    // For automated checks only: launch with -demoFaces <enrol.jpg> <other.jpg>
                    // (plus -serverAddress and -pairingCode) to enrol a face from a file,
                    // look at both pictures, print what the server said, and forget the face.
                    let arguments = ProcessInfo.processInfo.arguments
                    guard let at = arguments.firstIndex(of: "-demoFaces"), arguments.count > at + 2,
                          let known = FileManager.default.contents(atPath: arguments[at + 1]),
                          let other = FileManager.default.contents(atPath: arguments[at + 2]) else { return }
                    let defaults = UserDefaults.standard
                    faces.speaks = false
                    faces.start(server: defaults.string(forKey: "serverAddress") ?? "", code: defaults.string(forKey: "pairingCode") ?? "")
                    func pause() async { try? await Task.sleep(nanoseconds: 1_500_000_000) }
                    await pause()
                    print("demoFaces state:", faces.state)
                    faces.enrol(name: "Demo check", relationship: "test", jpeg: known)
                    await pause()
                    print("demoFaces enrolled:", faces.people.map(\.name), faces.notice ?? "")
                    faces.look(known)
                    await pause()
                    print("demoFaces known picture:", faces.inView.map { "\($0.name) \($0.match ?? "")" }, "strangers:", faces.strangers)
                    faces.look(other)
                    await pause()
                    print("demoFaces other picture:", faces.inView.map(\.name), "strangers:", faces.strangers)
                    faces.forget("Demo check")
                    await pause()
                    print("demoFaces after forget:", faces.people.map(\.name))
                    faces.stop()
                }
                .task {
                    // For automated checks only: launch with -demoPretend to connect to the
                    // pretend band and switch its microphone on without touching the screen.
                    guard ProcessInfo.processInfo.arguments.contains("-demoPretend") else { return }
                    band.connect(pretend: true)
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    await band.setMic(true)
                }
        }
    }
}
