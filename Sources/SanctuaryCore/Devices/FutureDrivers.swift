import Foundation

// MARK: - Driver catalogue (shown in the Devices tab)

/// Metadata for drivers planned in later phases. The Devices tab lists these
/// with a "Not connected — Phase N" status until real drivers land.
public struct FutureDriverInfo {
    public let name: String
    public let phase: String
    public let description: String

    public init(name: String, phase: String, description: String) {
        self.name = name
        self.phase = phase
        self.description = description
    }
}

public let futureDrivers: [FutureDriverInfo] = [
    FutureDriverInfo(
        name: "OBS Studio",
        phase: "Phase 2",
        description: "Stream start/stop, recording, and software video switching via the obs-websocket API."
    ),
    FutureDriverInfo(
        name: "VideoPsalms",
        phase: "Phase 2",
        description: "Remote lyrics control (next/previous slide, song select). Requires the booth PC on the same network as the Mac hub."
    ),
    FutureDriverInfo(
        name: "DMX Lighting",
        phase: "Phase 3",
        description: "Stage lighting scenes through a USB-DMX interface (e.g. Enttec Open DMX)."
    ),
    FutureDriverInfo(
        name: "Digital Mixer",
        phase: "Phase 3",
        description: "Upgrade path: replace the analog VGM14 with an OSC/MIDI-capable digital mixer for true remote-controlled faders."
    ),
]

// MARK: - Phase 2/3 driver stubs

// TODO(Phase 2): Implement against the obs-websocket protocol
// (https://github.com/obsproject/obs-websocket). Needs: stream start/stop,
// recording toggle, scene switching, and status polling.
public final class OBSWebSocketDriver: DeviceControl {
    public let name = "OBS Studio"
    public private(set) var isConnected = false

    public init() {}

    public func connect() async throws {
        // TODO: open WebSocket to ws://booth-mac:4455, authenticate, subscribe to events.
    }

    public func disconnect() async {
        // TODO: close the socket.
    }
}

// TODO(Phase 2): Implement VideoPsalms remote control. First verify what the
// booth's VideoPsalms install exposes (its own remote app? a network API?).
// Fallback: drive slides via UI automation or migrate lyrics to the Mac.
public final class VideoPsalmsDriver: DeviceControl {
    public let name = "VideoPsalms"
    public private(set) var isConnected = false

    public init() {}

    public func connect() async throws {
        // TODO: connect to the VideoPsalms remote endpoint on the booth PC.
    }

    public func disconnect() async {
        // TODO: disconnect.
    }
}

// TODO(Phase 3): Implement DMX output via a USB-DMX interface (e.g. Enttec
// Open DMX over serial). Needs: scene storage, fade between scenes,
// blackout.
public final class DMXDriver: DeviceControl {
    public let name = "DMX Lighting"
    public private(set) var isConnected = false

    public init() {}

    public func connect() async throws {
        // TODO: open the serial port to the USB-DMX interface.
    }

    public func disconnect() async {
        // TODO: blackout and close the port.
    }
}
