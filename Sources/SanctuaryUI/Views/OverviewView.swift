import SwiftUI
import SanctuaryCore

/// At-a-glance service status: current/next cue, audio, sync, quick actions.
public struct OverviewView: View {
    @EnvironmentObject var store: BoothStore

    public init() {}

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260), spacing: 16)],
                spacing: 16
            ) {
                cueCard
                audioCard
                syncCard
                actionsCard
            }
            .padding()
        }
        .navigationTitle("Overview")
    }

    // MARK: - Cards

    private var cueCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if let current = store.currentCue {
                    Label("Now", systemImage: "play.circle.fill")
                        .font(.headline)
                    Text(current.title)
                        .font(.title2.bold())
                    Text(current.kind.displayName)
                        .foregroundStyle(.secondary)
                    if !current.notes.isEmpty {
                        Text(current.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No cues").foregroundStyle(.secondary)
                }
                Divider()
                if let next = store.nextCue {
                    HStack {
                        Label("Next", systemImage: "arrow.right.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(next.title)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Service", systemImage: "list.bullet.rectangle")
        }
    }

    private var audioCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                let playing = store.playbackEngine.trackStates.values.filter { $0 == .playing }.count
                HStack {
                    Text("\(playing)")
                        .font(.largeTitle.bold())
                    Text(playing == 1 ? "track playing" : "tracks playing")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.tracks) { track in
                    HStack {
                        Image(systemName: track.kindIcon(
                            state: store.playbackEngine.trackStates[track.id] ?? .stopped
                        ))
                        .foregroundStyle(.secondary)
                        Text(track.name)
                        Spacer()
                        if track.isMuted {
                            Text("Muted").font(.caption).foregroundStyle(.orange)
                        }
                    }
                    .font(.callout)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Audio", systemImage: "speaker.wave.2.fill")
        }
    }

    private var syncCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(store.sync.connectionState == .connected ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(store.sync.connectionState.displayName)
                        .font(.headline)
                }
                if store.sync.connectedPeerNames.isEmpty {
                    Text("Looking for the other device on the booth network…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.sync.connectedPeerNames, id: \.self) { name in
                        Label(name, systemImage: "desktopcomputer")
                            .font(.callout)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Sync", systemImage: "wifi")
        }
    }

    private var actionsCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                Button {
                    store.advanceCue()
                } label: {
                    Label("Advance Cue", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(role: .destructive) {
                    store.stopAllAudio()
                } label: {
                    Label("All Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
        } label: {
            Label("Quick Actions", systemImage: "bolt.fill")
        }
    }
}

// MARK: - Small helper

private extension AudioTrack {
    func kindIcon(state: TrackPlaybackState) -> String {
        switch state {
        case .playing: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .stopped: return "circle"
        }
    }
}
