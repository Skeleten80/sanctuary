import XCTest
@testable import SanctuaryCore

final class ModelTests: XCTestCase {

    // MARK: - Checklist

    func testChecklistProgress() {
        var list = Checklist(
            title: "Sunday Setup",
            role: "Sound",
            items: [
                ChecklistItem(title: "a", isComplete: true),
                ChecklistItem(title: "b"),
                ChecklistItem(title: "c"),
                ChecklistItem(title: "d"),
            ]
        )
        XCTAssertEqual(list.completedCount, 1)
        XCTAssertEqual(list.progress, 0.25, accuracy: 0.0001)
        XCTAssertFalse(list.isComplete)

        list.items[1].isComplete = true
        list.items[2].isComplete = true
        list.items[3].isComplete = true
        XCTAssertEqual(list.progress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(list.isComplete)
    }

    func testEmptyChecklistCountsAsComplete() {
        let list = Checklist(title: "Empty", role: "Sound", items: [])
        XCTAssertEqual(list.progress, 1.0, accuracy: 0.0001)
    }

    // MARK: - RunOfShow

    func testRunOfShowTotalDuration() {
        let ros = RunOfShow(
            title: "Test",
            date: Date(),
            cues: [
                Cue(title: "A", kind: .song, durationSeconds: 60),
                Cue(title: "B", kind: .sermon, durationSeconds: 120),
            ]
        )
        XCTAssertEqual(ros.totalDuration, 180, accuracy: 0.0001)
    }

    func testCueAtBounds() {
        let ros = RunOfShow(
            title: "Test",
            date: Date(),
            cues: [Cue(title: "Only", kind: .prayer, durationSeconds: 30)]
        )
        XCTAssertEqual(ros.cue(at: 0)?.title, "Only")
        XCTAssertNil(ros.cue(at: 1))
        XCTAssertNil(ros.cue(at: -1))
    }

    // MARK: - SyncMessage

    func testSyncMessageRoundTrip() throws {
        let id = UUID()
        let messages: [SyncMessage] = [
            .checklistItemToggled(checklistID: id, itemID: id, isComplete: true),
            .cueAdvanced(cueID: id),
            .transport(command: .nextCue),
            .transport(command: .stop),
            .trackTransport(trackID: id, command: .pause),
            .faderChanged(trackID: id, volume: 0.42),
            .muteChanged(trackID: id, isMuted: true),
            .masterVolumeChanged(volume: 0.9),
            .fullStateRequest,
            .fullStateSnapshot(data: Data("hello".utf8)),
        ]
        for message in messages {
            let decoded = try SyncMessage.decoded(from: try message.encoded())
            XCTAssertEqual(decoded, message, "round-trip failed for \(message)")
        }
    }

    func testSyncMessageCarriesProtocolVersion() throws {
        let data = try SyncMessage.fullStateRequest.encoded()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["version"] as? Int, SyncMessage.protocolVersion)
        XCTAssertEqual(json?["type"] as? String, "fullStateRequest")
    }

    func testBoothSnapshotRoundTrip() throws {
        let snapshot = BoothSnapshot(
            checklists: [Checklist(title: "T", role: "R", items: [ChecklistItem(title: "i")])],
            runOfShow: RunOfShow(title: "S", date: Date(), cues: [
                Cue(title: "C", kind: .song, durationSeconds: 60)
            ]),
            currentCueIndex: 0,
            tracks: [AudioTrack(name: "T", volume: 0.5)]
        )
        let data = try JSONEncoder().encode(snapshot)
        let back = try JSONDecoder().decode(BoothSnapshot.self, from: data)
        XCTAssertEqual(back.runOfShow.title, "S")
        XCTAssertEqual(back.checklists.first?.items.count, 1)
        XCTAssertEqual(back.tracks.first?.volume ?? 0, 0.5, accuracy: 0.0001)
    }
}
