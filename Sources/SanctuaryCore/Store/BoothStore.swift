import Combine
import Foundation

/// Central state for the booth. Owns the checklists, run of show, audio
/// tracks, the playback engine, and the sync service — and keeps them
/// consistent with the remote peer.
///
/// Convention: public methods are LOCAL user actions (apply + broadcast).
/// Incoming `SyncMessage`s go through `applyRemote(_:)`, which never
/// re-broadcasts (no echo loops).
public final class BoothStore: ObservableObject {
    @Published public var checklists: [Checklist] = []
    @Published public var runOfShow: RunOfShow
    @Published public var currentCueIndex: Int = 0
    @Published public var currentCueStartedAt: Date? = nil
    @Published public var tracks: [AudioTrack] = []

    public let playbackEngine = PlaybackEngine()
    public let sync = BoothSyncService()

    public init() {
        let seed = Self.makeSeed()
        self.checklists = seed.checklists
        self.runOfShow = seed.runOfShow
        self.tracks = seed.tracks
        self.currentCueStartedAt = Date()

        sync.onMessageReceived = { [weak self] message, _ in
            self?.applyRemote(message)
        }
        sync.onPeerConnected = { [weak self] _ in
            // The iPad follows the Mac: ask for full state on connect.
            // The Mac is the source of truth and only answers.
            #if os(iOS)
            self?.requestFullState()
            #endif
        }

        for track in tracks {
            playbackEngine.load(track: track)
        }
        sync.start()
    }

    // MARK: - Checklists

    public func toggleChecklistItem(checklistID: UUID, itemID: UUID) {
        guard let ci = checklists.firstIndex(where: { $0.id == checklistID }),
              let ii = checklists[ci].items.firstIndex(where: { $0.id == itemID })
        else { return }
        let newValue = !checklists[ci].items[ii].isComplete
        setChecklistItem(checklistID: checklistID, itemID: itemID, isComplete: newValue, broadcast: true)
    }

    public func resetChecklist(id: UUID) {
        guard let ci = checklists.firstIndex(where: { $0.id == id }) else { return }
        for item in checklists[ci].items {
            setChecklistItem(checklistID: id, itemID: item.id, isComplete: false, broadcast: true)
        }
    }

    private func setChecklistItem(checklistID: UUID, itemID: UUID, isComplete: Bool, broadcast: Bool) {
        guard let ci = checklists.firstIndex(where: { $0.id == checklistID }),
              let ii = checklists[ci].items.firstIndex(where: { $0.id == itemID })
        else { return }
        checklists[ci].items[ii].isComplete = isComplete
        if broadcast {
            sync.send(.checklistItemToggled(checklistID: checklistID, itemID: itemID, isComplete: isComplete))
        }
    }

    // MARK: - Run of show

    public var currentCue: Cue? { runOfShow.cue(at: currentCueIndex) }
    public var nextCue: Cue? { runOfShow.cue(at: currentCueIndex + 1) }

    public func advanceCue() {
        goToCue(index: min(currentCueIndex + 1, runOfShow.cues.count - 1), broadcast: true)
    }

    public func previousCue() {
        goToCue(index: max(0, currentCueIndex - 1), broadcast: true)
    }

    public func goToCue(index: Int) {
        goToCue(index: index, broadcast: true)
    }

    private func goToCue(index: Int, broadcast: Bool) {
        guard runOfShow.cues.indices.contains(index),
              let cue = runOfShow.cue(at: index)
        else { return }
        currentCueIndex = index
        currentCueStartedAt = Date()
        if broadcast {
            sync.send(.cueAdvanced(cueID: cue.id))
        }
    }

    // MARK: - Audio

    public func playTrack(id: UUID) {
        playbackEngine.play(trackID: id)
        sync.send(.trackTransport(trackID: id, command: .play))
    }

    public func pauseTrack(id: UUID) {
        playbackEngine.pause(trackID: id)
        sync.send(.trackTransport(trackID: id, command: .pause))
    }

    public func stopTrack(id: UUID) {
        playbackEngine.stop(trackID: id)
        sync.send(.trackTransport(trackID: id, command: .stop))
    }

    public func setTrackVolume(id: UUID, volume: Float) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[i].volume = volume
        playbackEngine.setVolume(trackID: id, volume: volume)
        sync.send(.faderChanged(trackID: id, volume: volume))
    }

    public func setTrackMuted(id: UUID, isMuted: Bool) {
        guard let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[i].isMuted = isMuted
        playbackEngine.setMuted(trackID: id, isMuted: isMuted)
        sync.send(.muteChanged(trackID: id, isMuted: isMuted))
    }

    /// Fades the track out over its configured fade duration, then stops it.
    /// Remote peers receive a plain stop (no fade) — acceptable for Phase 1.
    public func fadeOutTrack(id: UUID) {
        let duration = tracks.first(where: { $0.id == id })?.fadeDuration ?? 2.0
        playbackEngine.fadeOut(trackID: id, duration: duration)
        sync.send(.trackTransport(trackID: id, command: .stop))
    }

    public func stopAllAudio() {
        playbackEngine.stopAll()
        sync.send(.transport(command: .stop))
    }

    public func setMasterVolume(_ volume: Float) {
        playbackEngine.masterVolume = volume
        sync.send(.masterVolumeChanged(volume: volume))
    }

    // MARK: - Remote messages

    private func applyRemote(_ message: SyncMessage) {
        switch message {
        case let .checklistItemToggled(checklistID, itemID, isComplete):
            setChecklistItem(checklistID: checklistID, itemID: itemID, isComplete: isComplete, broadcast: false)

        case let .cueAdvanced(cueID):
            if let index = runOfShow.cues.firstIndex(where: { $0.id == cueID }) {
                goToCue(index: index, broadcast: false)
            }

        case let .transport(command):
            switch command {
            case .play:
                for id in tracks.map(\.id) where playbackEngine.trackStates[id] == .paused {
                    playbackEngine.play(trackID: id)
                }
            case .pause:
                for id in tracks.map(\.id) where playbackEngine.trackStates[id] == .playing {
                    playbackEngine.pause(trackID: id)
                }
            case .stop:
                playbackEngine.stopAll()
            case .nextCue:
                goToCue(index: min(currentCueIndex + 1, runOfShow.cues.count - 1), broadcast: false)
            case .prevCue:
                goToCue(index: max(0, currentCueIndex - 1), broadcast: false)
            }

        case let .trackTransport(trackID, command):
            switch command {
            case .play: playbackEngine.play(trackID: trackID)
            case .pause: playbackEngine.pause(trackID: trackID)
            case .stop: playbackEngine.stop(trackID: trackID)
            }

        case let .faderChanged(trackID, volume):
            if let i = tracks.firstIndex(where: { $0.id == trackID }) {
                tracks[i].volume = volume
                playbackEngine.setVolume(trackID: trackID, volume: volume)
            }

        case let .muteChanged(trackID, isMuted):
            if let i = tracks.firstIndex(where: { $0.id == trackID }) {
                tracks[i].isMuted = isMuted
                playbackEngine.setMuted(trackID: trackID, isMuted: isMuted)
            }

        case let .masterVolumeChanged(volume):
            playbackEngine.masterVolume = volume

        case .fullStateRequest:
            sendFullState()

        case let .fullStateSnapshot(data):
            applySnapshot(data)
        }
    }

    private func requestFullState() {
        sync.send(.fullStateRequest)
    }

    private func sendFullState() {
        let snapshot = BoothSnapshot(
            checklists: checklists,
            runOfShow: runOfShow,
            currentCueIndex: currentCueIndex,
            tracks: tracks
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            sync.send(.fullStateSnapshot(data: data))
        } catch {
            print("[BoothStore] snapshot encode failed: \(error)")
        }
    }

    private func applySnapshot(_ data: Data) {
        do {
            let snapshot = try JSONDecoder().decode(BoothSnapshot.self, from: data)
            checklists = snapshot.checklists
            runOfShow = snapshot.runOfShow
            currentCueIndex = snapshot.currentCueIndex
            currentCueStartedAt = Date()
            tracks = snapshot.tracks
            // Rebuild engine state from the new track list. Stops anything
            // currently playing — acceptable for a fresh join in Phase 1.
            playbackEngine.unloadAll()
            for track in tracks {
                playbackEngine.load(track: track)
            }
        } catch {
            print("[BoothStore] snapshot decode failed: \(error)")
        }
    }

    // MARK: - Seed data

    private struct Seed {
        var checklists: [Checklist]
        var runOfShow: RunOfShow
        var tracks: [AudioTrack]
    }

    private static func makeSeed() -> Seed {
        let setup = Checklist(
            title: "Sunday Setup",
            role: "Sound",
            items: [
                ChecklistItem(title: "Power on booth gear (mixer → amps → projector)"),
                ChecklistItem(title: "VGM14: all channel faders at unity, mutes off"),
                ChecklistItem(title: "Test pastor's mic"),
                ChecklistItem(title: "Test wireless handheld mics"),
                ChecklistItem(title: "Test instruments / DI boxes"),
                ChecklistItem(title: "Projector on — VideoPsalms loaded with today's set"),
                ChecklistItem(title: "Preshow audio playing from Mac (USB → mixer)"),
                ChecklistItem(title: "Stage monitor levels set"),
                ChecklistItem(title: "House lights to preservice preset"),
                ChecklistItem(title: "Doors open — background music low"),
            ]
        )
        let teardown = Checklist(
            title: "Teardown",
            role: "Sound",
            items: [
                ChecklistItem(title: "Fade out house audio"),
                ChecklistItem(title: "Mute all VGM14 channels"),
                ChecklistItem(title: "Power down projector"),
                ChecklistItem(title: "Collect wireless mics — place on chargers"),
                ChecklistItem(title: "Power down amps, then mixer"),
                ChecklistItem(title: "Lock booth door"),
            ]
        )

        let runOfShow = RunOfShow(
            title: "Sunday Morning Service",
            date: Date(),
            cues: [
                Cue(title: "Pre-Service Music", kind: .transition, durationSeconds: 600,
                    notes: "Preshow loop from Mac, low under doors-open"),
                Cue(title: "Welcome & Announcements", kind: .announcement, durationSeconds: 300),
                Cue(title: "Worship Set — Song 1", kind: .song, durationSeconds: 270),
                Cue(title: "Worship Set — Song 2", kind: .song, durationSeconds: 270),
                Cue(title: "Worship Set — Song 3", kind: .song, durationSeconds: 300),
                Cue(title: "Pastoral Prayer", kind: .prayer, durationSeconds: 180,
                    notes: "Pastor's mic only, house music out"),
                Cue(title: "Sermon", kind: .sermon, durationSeconds: 2100,
                    notes: "Sermon bumper in/out from Mac"),
                Cue(title: "Closing Song", kind: .song, durationSeconds: 300),
                Cue(title: "Post-Service Music", kind: .transition, durationSeconds: 600,
                    notes: "Preshow loop back up as people leave"),
            ]
        )

        let tracks = [
            AudioTrack(name: "Preshow Loop", volume: 0.7, shouldLoop: true),
            AudioTrack(name: "Worship Pad", volume: 0.6, shouldLoop: true),
            AudioTrack(name: "Sermon Bumper", volume: 0.8, fadeDuration: 3.0),
        ]

        return Seed(checklists: [setup, teardown], runOfShow: runOfShow, tracks: tracks)
    }
}
