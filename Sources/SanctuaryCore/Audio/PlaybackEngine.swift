import AVFoundation
import Combine
import Foundation

/// Per-track playback state, published for the UI.
public enum TrackPlaybackState: String {
    case stopped
    case playing
    case paused
}

/// Software audio playback engine for the Mac hub.
///
/// Each track gets its own `AVAudioPlayerNode` -> `AVAudioMixerNode` (per-track
/// volume/mute + level tap) -> master mixer -> output. This is the fader the
/// dashboard controls in Phase 1; it has nothing to do with the analog VGM14.
///
/// Threading: call all public methods from the main thread. Level-meter
/// callbacks are marshalled back to main internally.
public final class PlaybackEngine: ObservableObject {
    @Published public private(set) var trackStates: [UUID: TrackPlaybackState] = [:]
    /// 0.0 ... 1.0 per track, updated ~10x/sec from the tap.
    @Published public private(set) var levels: [UUID: Float] = [:]
    @Published public var masterVolume: Float = 1.0 {
        didSet { masterMixer.volume = masterVolume }
    }

    private let engine = AVAudioEngine()
    private let masterMixer = AVAudioMixerNode()

    private var players: [UUID: AVAudioPlayerNode] = [:]
    private var trackMixers: [UUID: AVAudioMixerNode] = [:]
    private var audioFiles: [UUID: AVAudioFile] = [:]
    private var volumes: [UUID: Float] = [:]
    private var muted: [UUID: Bool] = [:]
    private var loopFlags: [UUID: Bool] = [:]
    /// Guards the loop re-schedule against stale callbacks after stop().
    private var generations: [UUID: Int] = [:]
    private var fadeTimers: [UUID: Timer] = [:]
    private var lastMeterUpdate = Date.distantPast

    public init() {
        engine.attach(masterMixer)
        engine.connect(masterMixer, to: engine.mainMixerNode, format: nil)
        masterMixer.volume = masterVolume
        configureAudioSession()
    }

    deinit {
        engine.stop()
    }

    // MARK: - Loading

    /// Loads (or reloads) a track. Missing audio file => logs and leaves the
    /// track unloadable until a file is added to `Media/`. Never throws.
    public func load(track: AudioTrack) {
        unload(trackID: track.id)
        guard let url = resolveURL(for: track) else {
            print("[PlaybackEngine] no audio file for '\(track.name)' — drop it in Sources/SanctuaryCore/Media/")
            return
        }
        do {
            let file = try AVAudioFile(forReading: url)
            let player = AVAudioPlayerNode()
            let mixer = AVAudioMixerNode()
            engine.attach(player)
            engine.attach(mixer)
            engine.connect(player, to: mixer, format: file.processingFormat)
            engine.connect(mixer, to: masterMixer, format: file.processingFormat)

            players[track.id] = player
            trackMixers[track.id] = mixer
            audioFiles[track.id] = file
            volumes[track.id] = track.volume
            muted[track.id] = track.isMuted
            loopFlags[track.id] = track.shouldLoop
            generations[track.id] = 0
            applyVolume(trackID: track.id)
            trackStates[track.id] = .stopped
            levels[track.id] = 0
            installLevelTap(trackID: track.id, mixer: mixer)
            startEngineIfNeeded()
        } catch {
            print("[PlaybackEngine] failed to load '\(track.name)': \(error)")
        }
    }

    public func unload(trackID: UUID) {
        cancelFade(trackID: trackID)
        if let player = players[trackID] {
            player.stop()
            engine.detach(player)
        }
        if let mixer = trackMixers[trackID] {
            mixer.removeTap(onBus: 0)
            engine.detach(mixer)
        }
        players.removeValue(forKey: trackID)
        trackMixers.removeValue(forKey: trackID)
        audioFiles.removeValue(forKey: trackID)
        volumes.removeValue(forKey: trackID)
        muted.removeValue(forKey: trackID)
        loopFlags.removeValue(forKey: trackID)
        generations.removeValue(forKey: trackID)
        trackStates.removeValue(forKey: trackID)
        levels.removeValue(forKey: trackID)
    }

    /// Whether a track's nodes are currently attached to the engine.
    public func isLoaded(trackID: UUID) -> Bool {
        players[trackID] != nil
    }

    public func unloadAll() {
        for id in Array(players.keys) { unload(trackID: id) }
    }

    // MARK: - Transport

    public func play(trackID: UUID) {
        guard let player = players[trackID], audioFiles[trackID] != nil else { return }
        startEngineIfNeeded()
        if trackStates[trackID] == .paused {
            player.play()
        } else {
            generations[trackID, default: 0] += 1
            player.stop()
            schedule(trackID: trackID)
            player.play()
        }
        trackStates[trackID] = .playing
    }

    public func pause(trackID: UUID) {
        guard players[trackID] != nil, trackStates[trackID] == .playing else { return }
        players[trackID]?.pause()
        trackStates[trackID] = .paused
    }

    public func stop(trackID: UUID) {
        cancelFade(trackID: trackID)
        generations[trackID, default: 0] += 1
        players[trackID]?.stop()
        trackStates[trackID] = .stopped
        levels[trackID] = 0
    }

    public func stopAll() {
        for id in Array(players.keys) { stop(trackID: id) }
    }

    // MARK: - Mixing

    public func setVolume(trackID: UUID, volume: Float) {
        volumes[trackID] = min(1, max(0, volume))
        applyVolume(trackID: trackID)
    }

    public func setMuted(trackID: UUID, isMuted: Bool) {
        muted[trackID] = isMuted
        applyVolume(trackID: trackID)
    }

    /// Ramps the track's output to silence, then stops it.
    /// The stored volume is restored so the next play() starts at full level.
    public func fadeOut(trackID: UUID, duration: TimeInterval) {
        cancelFade(trackID: trackID)
        guard trackMixers[trackID] != nil else { return }
        let startVolume = volumes[trackID] ?? 1.0
        let steps = 30
        var step = 0
        let timer = Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            step += 1
            let v = startVolume * (1 - Float(step) / Float(steps))
            self.trackMixers[trackID]?.volume = max(0, v)
            if step >= steps {
                timer.invalidate()
                self.fadeTimers[trackID] = nil
                self.stop(trackID: trackID)
            }
        }
        fadeTimers[trackID] = timer
    }

    // MARK: - Private

    private func schedule(trackID: UUID) {
        guard let player = players[trackID],
              let file = audioFiles[trackID] else { return }
        let generation = generations[trackID, default: 0]
        if loopFlags[trackID] == true {
            player.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self else { return }
                // Only re-queue if nothing stopped/restarted the track meanwhile.
                if self.generations[trackID] == generation,
                   self.trackStates[trackID] == .playing {
                    self.schedule(trackID: trackID)
                }
            }
        } else {
            player.scheduleFile(file, at: nil) { [weak self] _ in
                DispatchQueue.main.async {
                    // Natural end of a non-looping track.
                    if self?.generations[trackID] == generation {
                        self?.trackStates[trackID] = .stopped
                        self?.levels[trackID] = 0
                    }
                }
            }
        }
    }

    private func applyVolume(trackID: UUID) {
        let v = volumes[trackID] ?? 1.0
        let m = muted[trackID] ?? false
        trackMixers[trackID]?.volume = m ? 0 : v
    }

    private func cancelFade(trackID: UUID) {
        fadeTimers[trackID]?.invalidate()
        fadeTimers[trackID] = nil
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("[PlaybackEngine] engine start failed: \(error)")
        }
    }

    private func resolveURL(for track: AudioTrack) -> URL? {
        if let url = track.fileURL { return url }
        guard let name = track.fileName else { return nil }
        return Bundle.module.url(
            forResource: name,
            withExtension: track.fileExtension,
            subdirectory: "Media"
        )
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[PlaybackEngine] audio session failed: \(error)")
        }
        #endif
        // macOS needs no explicit session configuration.
    }

    private func installLevelTap(trackID: UUID, mixer: AVAudioMixerNode) {
        mixer.removeTap(onBus: 0)
        mixer.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let self else { return }
            let level = Self.rmsLevel(of: buffer)
            let now = Date()
            guard now.timeIntervalSince(self.lastMeterUpdate) > 0.1 else { return }
            self.lastMeterUpdate = now
            DispatchQueue.main.async { self.levels[trackID] = level }
        }
    }

    private static func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0 ..< count {
            let s = channelData[0][i]
            sum += s * s
        }
        let rms = sqrt(sum / Float(count))
        return min(1, rms * 2) // crude scaling so speech/music visibly moves the meter
    }
}
