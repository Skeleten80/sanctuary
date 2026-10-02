import Foundation

/// A single tappable item on a checklist (e.g. "Test pastor's mic").
public struct ChecklistItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var isComplete: Bool
    public var notes: String

    public init(
        id: UUID = UUID(),
        title: String,
        isComplete: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.notes = notes
    }
}

/// A named checklist owned by a booth role (Sound, Video, Producer...).
public struct Checklist: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var role: String
    public var items: [ChecklistItem]

    public init(
        id: UUID = UUID(),
        title: String,
        role: String,
        items: [ChecklistItem] = []
    ) {
        self.id = id
        self.title = title
        self.role = role
        self.items = items
    }

    public var completedCount: Int {
        items.filter(\.isComplete).count
    }

    /// 0.0 ... 1.0. An empty checklist counts as complete.
    public var progress: Double {
        guard !items.isEmpty else { return 1 }
        return Double(completedCount) / Double(items.count)
    }

    public var isComplete: Bool {
        !items.isEmpty && completedCount == items.count
    }
}
