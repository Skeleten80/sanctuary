import Foundation

/// The kind of a run-of-show cue. Drives the icon shown in the UI.
public enum CueKind: String, Codable, CaseIterable, Equatable {
    case song
    case prayer
    case sermon
    case announcement
    case video
    case transition

    public var displayName: String { rawValue.capitalized }

    public var systemImage: String {
        switch self {
        case .song: return "music.note"
        case .prayer: return "book.fill"
        case .sermon: return "mic.fill"
        case .announcement: return "megaphone.fill"
        case .video: return "video.fill"
        case .transition: return "arrow.right.circle.fill"
        }
    }
}

/// One entry in the run of show (a song, prayer, sermon segment, ...).
public struct Cue: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var kind: CueKind
    public var durationSeconds: TimeInterval
    public var notes: String
    /// Optional link to an AudioTrack that belongs with this cue.
    public var audioTrackID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        kind: CueKind,
        durationSeconds: TimeInterval,
        notes: String = "",
        audioTrackID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.audioTrackID = audioTrackID
    }
}

/// The ordered plan for one service.
public struct RunOfShow: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var date: Date
    public var cues: [Cue]

    public init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        cues: [Cue] = []
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.cues = cues
    }

    /// Safe indexed access; nil when out of bounds.
    public func cue(at index: Int) -> Cue? {
        guard cues.indices.contains(index) else { return nil }
        return cues[index]
    }

    public var totalDuration: TimeInterval {
        cues.reduce(0) { $0 + $1.durationSeconds }
    }
}
