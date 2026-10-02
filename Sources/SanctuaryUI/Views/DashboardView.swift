import SwiftUI
import SanctuaryCore

/// Root navigation. Sidebar on macOS, tabs on iPad — the Apple-native way.
public struct DashboardView: View {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case overview
        case checklists
        case runOfShow
        case audio
        case devices

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .checklists: return "Checklists"
            case .runOfShow: return "Run of Show"
            case .audio: return "Audio"
            case .devices: return "Devices"
            }
        }

        var systemImage: String {
            switch self {
            case .overview: return "house.fill"
            case .checklists: return "checklist"
            case .runOfShow: return "list.bullet.rectangle"
            case .audio: return "slider.horizontal.3"
            case .devices: return "cable.connector"
            }
        }
    }

    @State private var selection: Tab = .overview

    public init() {}

    public var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(
                Tab.allCases,
                selection: Binding<Tab?>(
                    get: { selection },
                    set: { selection = $0 ?? .overview }
                )
            ) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .navigationTitle("Sanctuary")
        } detail: {
            tabContent(for: selection)
        }
        #else
        TabView(selection: $selection) {
            ForEach(Tab.allCases) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        #endif
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .overview: OverviewView()
        case .checklists: ChecklistView()
        case .runOfShow: RunOfShowView()
        case .audio: AudioMixerView()
        case .devices: DevicePlaceholderView()
        }
    }
}
