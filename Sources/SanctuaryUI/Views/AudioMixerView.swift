import SwiftUI
import SanctuaryCore

/// Software mixing surface: one channel strip per playback track plus a
/// master section. These faders drive the Mac's AVAudioEngine — NOT the
/// analog VGM14 (which has no remote control).
public struct AudioMixerView: View {
    @EnvironmentObject var store: BoothStore

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if store.tracks.isEmpty {
                    ContentUnavailableView(
                        "No Audio Tracks",
                        systemImage: "music.note",
                        description: Text("Add tracks to the store to mix them here.")
                    )
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach($store.tracks) { $track in
                            ChannelStripView(track: $track)
                        }
                    }
                }
                MasterSectionView(engine: store.playbackEngine)
            }
            .padding()
        }
        .navigationTitle("Audio")
    }
}

// MARK: - Channel strip

private struct ChannelStripView: View {
    @Binding var track: AudioTrack
    @EnvironmentObject var store: BoothStore

    private var engine: PlaybackEngine { store.playbackEngine }
    private var state: TrackPlaybackState {
        engine.trackStates[track.id] ?? .stopped
    }
    private var level: Float {
        engine.levels[track.id] ?? 0
    }

    var body: some View {
        GroupBox {
            VStack(spacing: 10) {
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)

                LevelMeter(level: level)

                // Fader
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: $track.volume, in: 0...1)
                        .onChange(of: track.volume) { newValue in
                            store.setTrackVolume(id: track.id, volume: newValue)
                        }
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }

                // Transport + mute
                HStack(spacing: 12) {
                    Button {
                        if state == .playing {
                            store.pauseTrack(id: track.id)
                        } else {
                            store.playTrack(id: track.id)
                        }
                    } label: {
                        Image(systemName: state == .playing ? "pause.fill" : "play.fill")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!engine.isLoaded(trackID: track.id))

                    Button {
                        store.stopTrack(id: track.id)
                    } label: {
                        Image(systemName: "stop.fill")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        store.fadeOutTrack(id: track.id)
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                    .help("Fade out")

                    Spacer()

                    Button {
                        store.setTrackMuted(id: track.id, isMuted: !track.isMuted)
                    } label: {
                        Text(track.isMuted ? "Unmute" : "Mute")
                            .frame(minWidth: 64)
                    }
                    .buttonStyle(.bordered)
                    .tint(track.isMuted ? .orange : nil)
                }
                .imageScale(.medium)

                if state == .playing {
                    Text("Playing")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if state == .paused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Master section

private struct MasterSectionView: View {
    @ObservedObject var engine: PlaybackEngine
    @EnvironmentObject var store: BoothStore

    var body: some View {
        GroupBox {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Master")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(engine.masterVolume * 100))%")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $engine.masterVolume, in: 0...1)
                    .onChange(of: engine.masterVolume) { newValue in
                        store.setMasterVolume(newValue)
                    }
                Button(role: .destructive) {
                    store.stopAllAudio()
                } label: {
                    Label("All Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
        } label: {
            Label("Master Output", systemImage: "slider.horizontal.3")
        }
    }
}
