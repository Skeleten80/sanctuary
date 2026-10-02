import Foundation

/// Common interface every booth device driver implements.
/// Phase 1 ships no drivers — the Mac hub talks to nothing but its own
/// audio engine. Phase 2/3 drivers plug in here (see FutureDrivers.swift).
public protocol DeviceControl: AnyObject {
    /// Human-readable name shown in the Devices tab, e.g. "OBS Studio".
    var name: String { get }

    /// Current connection state. Drivers update this as they connect.
    var isConnected: Bool { get }

    /// Establish the connection (open socket, handshake, ...).
    func connect() async throws

    /// Tear it down cleanly.
    func disconnect() async
}
