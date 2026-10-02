import Foundation

// MARK: - Transport commands

/// Master transport: applies to cue navigation and to all audio tracks at once.
public enum TransportCommand: String, Codable, Equatable {
    case play      // resume every paused track
    case stop      // stop every track
    case pause     // pause every playing track
    case nextCue
    case prevCue
}

/// Per-track transport.
public enum TrackTransportCommand: String, Codable, Equatable {
    case play
    case stop
    case pause
}

// MARK: - Full-state snapshot

/// Everything needed to bring a freshly-connected peer up to date.
public struct BoothSnapshot: Codable, Equatable {
    public var checklists: [Checklist]
    public var runOfShow: RunOfShow
    public var currentCueIndex: Int
    public var tracks: [AudioTrack]

    public init(
        checklists: [Checklist],
        runOfShow: RunOfShow,
        currentCueIndex: Int,
        tracks: [AudioTrack]
    ) {
        self.checklists = checklists
        self.runOfShow = runOfShow
        self.currentCueIndex = currentCueIndex
        self.tracks = tracks
    }
}

// MARK: - SyncMessage

/// Every state change exchanged between the Mac hub and the iPad remote.
/// JSON-encoded (see `encoded()` / `decoded(from:)`) and sent over
/// MultipeerConnectivity as `.reliable` data.
public enum SyncMessage: Codable, Equatable {
    /// Bump when the wire format changes in a breaking way.
    public static let protocolVersion = 1

    case checklistItemToggled(checklistID: UUID, itemID: UUID, isComplete: Bool)
    case cueAdvanced(cueID: UUID)
    case transport(command: TransportCommand)
    case trackTransport(trackID: UUID, command: TrackTransportCommand)
    case faderChanged(trackID: UUID, volume: Float)
    case muteChanged(trackID: UUID, isMuted: Bool)
    case masterVolumeChanged(volume: Float)
    case fullStateRequest
    case fullStateSnapshot(data: Data)

    private enum CodingKeys: String, CodingKey {
        case version
        case type
        case checklistID
        case itemID
        case isComplete
        case cueID
        case command
        case trackCommand
        case trackID
        case volume
        case isMuted
        case data
    }

    private enum MessageType: String, Codable {
        case checklistItemToggled
        case cueAdvanced
        case transport
        case trackTransport
        case faderChanged
        case muteChanged
        case masterVolumeChanged
        case fullStateRequest
        case fullStateSnapshot
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Version is read (and could be validated) but not enforced yet.
        _ = try container.decodeIfPresent(Int.self, forKey: .version)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .checklistItemToggled:
            self = .checklistItemToggled(
                checklistID: try container.decode(UUID.self, forKey: .checklistID),
                itemID: try container.decode(UUID.self, forKey: .itemID),
                isComplete: try container.decode(Bool.self, forKey: .isComplete)
            )
        case .cueAdvanced:
            self = .cueAdvanced(
                cueID: try container.decode(UUID.self, forKey: .cueID)
            )
        case .transport:
            self = .transport(
                command: try container.decode(TransportCommand.self, forKey: .command)
            )
        case .trackTransport:
            self = .trackTransport(
                trackID: try container.decode(UUID.self, forKey: .trackID),
                command: try container.decode(TrackTransportCommand.self, forKey: .trackCommand)
            )
        case .faderChanged:
            self = .faderChanged(
                trackID: try container.decode(UUID.self, forKey: .trackID),
                volume: try container.decode(Float.self, forKey: .volume)
            )
        case .muteChanged:
            self = .muteChanged(
                trackID: try container.decode(UUID.self, forKey: .trackID),
                isMuted: try container.decode(Bool.self, forKey: .isMuted)
            )
        case .masterVolumeChanged:
            self = .masterVolumeChanged(
                volume: try container.decode(Float.self, forKey: .volume)
            )
        case .fullStateRequest:
            self = .fullStateRequest
        case .fullStateSnapshot:
            self = .fullStateSnapshot(
                data: try container.decode(Data.self, forKey: .data)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.protocolVersion, forKey: .version)
        switch self {
        case let .checklistItemToggled(checklistID, itemID, isComplete):
            try container.encode(MessageType.checklistItemToggled, forKey: .type)
            try container.encode(checklistID, forKey: .checklistID)
            try container.encode(itemID, forKey: .itemID)
            try container.encode(isComplete, forKey: .isComplete)
        case let .cueAdvanced(cueID):
            try container.encode(MessageType.cueAdvanced, forKey: .type)
            try container.encode(cueID, forKey: .cueID)
        case let .transport(command):
            try container.encode(MessageType.transport, forKey: .type)
            try container.encode(command, forKey: .command)
        case let .trackTransport(trackID, command):
            try container.encode(MessageType.trackTransport, forKey: .type)
            try container.encode(trackID, forKey: .trackID)
            try container.encode(command, forKey: .trackCommand)
        case let .faderChanged(trackID, volume):
            try container.encode(MessageType.faderChanged, forKey: .type)
            try container.encode(trackID, forKey: .trackID)
            try container.encode(volume, forKey: .volume)
        case let .muteChanged(trackID, isMuted):
            try container.encode(MessageType.muteChanged, forKey: .type)
            try container.encode(trackID, forKey: .trackID)
            try container.encode(isMuted, forKey: .isMuted)
        case let .masterVolumeChanged(volume):
            try container.encode(MessageType.masterVolumeChanged, forKey: .type)
            try container.encode(volume, forKey: .volume)
        case .fullStateRequest:
            try container.encode(MessageType.fullStateRequest, forKey: .type)
        case let .fullStateSnapshot(data):
            try container.encode(MessageType.fullStateSnapshot, forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }

    /// JSON wire encoding.
    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> SyncMessage {
        try JSONDecoder().decode(SyncMessage.self, from: data)
    }
}
