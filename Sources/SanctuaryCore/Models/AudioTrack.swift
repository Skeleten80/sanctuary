import Foundation

/// A software audio source played back by the Mac hub (backing track,
/// bumper, preshow loop...). Phase 1 faders control THESE tracks only —
/// the analog VGM14 mixer has no remote control.
public struct AudioTrack: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    /// Resource name inside the `Media/` bundle folder (no extension).
    /// Nil until a real audio file is dropped in.
    public var fileName: String?
    public var fileExtension: String
    /// 0.0 ... 1.0
    public var volume: Float
    public var isMuted: Bool
    public var fadeDuration: TimeInterval
    public var shouldLoop: Bool
    /// Resolved at load time; nil for seeded tracks until files exist.
    public var fileURL: URL?

    public init(
        id: UUID = UUID(),
        name: String,
        fileName: String? = nil,
        fileExtension: String = "m4a",
        volume: Float = 0.8,
        isMuted: Bool = false,
        fadeDuration: TimeInterval = 2.0,
        shouldLoop: Bool = false,
        fileURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.volume = volume
        self.isMuted = isMuted
        self.fadeDuration = fadeDuration
        self.shouldLoop = shouldLoop
        self.fileURL = fileURL
    }
}
