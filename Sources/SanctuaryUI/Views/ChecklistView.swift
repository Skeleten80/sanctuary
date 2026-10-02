import SwiftUI
import SanctuaryCore

/// Setup/teardown checklists with progress and reset.
public struct ChecklistView: View {
    @EnvironmentObject var store: BoothStore
    @State private var selectedID: UUID?

    public init() {}

    private var selected: Checklist? {
        store.checklists.first(where: { $0.id == selectedID })
            ?? store.checklists.first
    }

    public var body: some View {
        VStack(spacing: 0) {
            if store.checklists.count > 1 {
                Picker("Checklist", selection: Binding(
                    get: { selected?.id ?? store.checklists.first?.id },
                    set: { selectedID = $0 }
                )) {
                    ForEach(store.checklists) { list in
                        Text(list.title).tag(list.id as UUID?)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }

            if let list = selected {
                List {
                    Section {
                        ForEach(list.items) { item in
                            Button {
                                store.toggleChecklistItem(checklistID: list.id, itemID: item.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isComplete ? .green : .secondary)
                                        .imageScale(.large)
                                    VStack(alignment: .leading) {
                                        Text(item.title)
                                            .strikethrough(item.isComplete)
                                            .foregroundStyle(item.isComplete ? .secondary : .primary)
                                        if !item.notes.isEmpty {
                                            Text(item.notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(list.completedCount) of \(list.items.count) done")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Reset") {
                                    store.resetChecklist(id: list.id)
                                }
                                .font(.callout)
                            }
                            ProgressView(value: list.progress)
                        }
                        .textCase(nil)
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle(list.title)
            } else {
                ContentUnavailableView("No Checklists", systemImage: "checklist")
            }
        }
    }
}
