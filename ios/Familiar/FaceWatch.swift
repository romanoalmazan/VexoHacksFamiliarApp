import Foundation
import Observation

/// Runs "who is in front of the wearer": a camera (the Meta glasses or the iPhone) sends
/// one picture a second to the server through FaceClient. One of these lives for the whole
/// app, so faces keep being looked for while a conversation is being listened to.
@MainActor
@Observable
final class FaceWatch {
    let faces: FaceClient
    let glasses: GlassesCamera
    @ObservationIgnored let phone = PhoneCamera()

    private(set) var isOn = false
    private(set) var usingGlasses = false
    /// Why the iPhone's camera gives no pictures, or nil.
    private(set) var phoneProblem: String?

    init(faces: FaceClient, glasses: GlassesCamera) {
        self.faces = faces
        self.glasses = glasses
    }

    /// The newest picture from whichever camera is in use, for enrolling the face in view.
    var latestJPEG: Data? { usingGlasses ? glasses.latestJPEG : phone.latestJPEG }

    func start(server: String, code: String, useGlasses: Bool) {
        stop()
        isOn = true
        usingGlasses = useGlasses
        faces.start(server: server, code: code)
        if useGlasses {
            glasses.onFrame = { [faces] jpeg in faces.look(jpeg) }
            glasses.start()
        } else {
            phone.onProblem = { [weak self] problem in self?.phoneProblem = problem }
            phone.onFrame = { [faces] jpeg in faces.look(jpeg) }
            phone.start()
        }
    }

    func stop() {
        guard isOn else { return }
        isOn = false
        phone.onFrame = nil
        phone.stop()
        glasses.onFrame = nil
        glasses.stop()
        faces.stop()
    }
}
