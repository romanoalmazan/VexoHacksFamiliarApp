// A link carries contract frames between the phone and one band. Two kinds:
// BLELink (the real band over Bluetooth) and SimLink (a pretend band, for the Simulator).
import Foundation

public enum LinkEvent: Equatable, Sendable {
    /// Bluetooth is off, not allowed, or missing. The text says what to do.
    case unavailable(String)
    case searching
    case connecting
    /// Subscribed to the band's notifications: commands can be sent now.
    case ready
    /// The scan ended without seeing the band.
    case notFound
    /// The link closed. `byUs` is true when the app asked for it.
    case closed(byUs: Bool)
}

@MainActor
public protocol BandLink: AnyObject {
    var onEvent: ((LinkEvent) -> Void)? { get set }
    var onFrame: ((Data) -> Void)? { get set }
    /// Look for the band for up to `searchSeconds`, connect, and get ready for commands.
    func open(searchSeconds: TimeInterval)
    func send(_ frame: Data)
    func close()
}
