import SwiftUI
import SanctuaryCore

/// The service plan: cue list with live current-cue highlighting and timers.
public struct RunOfShowView: View {
    @EnvironmentObject var store: BoothStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            List {
                ForEach(Array(store.runOfShow.cues.enumerated()), id: \.element.id) { index, cue in
                    cueRow(cue, index: index)
                        .listRowBackground(
                            index == store.currentCueIndex
                                ? Color.accentColor.opacity(0.15)
                                : nil
                        )
                }
            }
        }
        .navigationTitle(store.runOfShow.title)
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total runtime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatClockHMS(store.runOfShow.totalDuration))
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                Spacer()
                Button {
                    store.previousCue()
                } label: {
                    Label("Back", systemImage: "backward.fill")
                }
                .buttonStyle(.bordered)
                .disabled(store.currentCueIndex == 0)

                Button {
                    store.advanceCue()
                } label: {
                    Label("Advance", systemImage: "forward.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.currentCueIndex >= store.runOfShow.cues.count - 1)
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Rows

    @ViewBuilder
    private func cueRow(_ cue: Cue, index: Int) -> some View {
        let isCurrent = index == store.currentCueIndex
        Button {
            store.goToCue(index: index)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: cue.kind.systemImage)
                    .foregroundStyle(isCurrent ? .accent : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cue.title)
                        .fontWeight(isCurrent ? .semibold : .regular)
                    Text(cue.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !cue.notes.isEmpty {
                        Text(cue.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if isCurrent, let startedAt = store.currentCueStartedAt {
                        let elapsed = max(0, now.timeIntervalSince(startedAt))
                        let remaining = cue.durationSeconds - elapsed
                        Text(formatClock(elapsed))
                            .font(.headline.monospacedDigit())
                        Text("-\(formatClock(remaining)) left")
                            .font(.caption)
                            .foregroundStyle(remaining < 60 ? .orange : .secondary)
                    } else {
                        Text(formatClock(cue.durationSeconds))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
