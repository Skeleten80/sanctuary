import SwiftUI
import SanctuaryCore

/// Lists the Phase 2/3 device drivers. Everything is a placeholder until
/// real drivers are implemented against actual booth hardware.
public struct DevicePlaceholderView: View {
    public init() {}

    public var body: some View {
        List {
            Section {
                ForEach(futureDrivers, id: \.name) { driver in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(driver.name)
                                .font(.headline)
                            Spacer()
                            Label("Not connected", systemImage: "cable.connector.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(driver.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(driver.phase)
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Planned integrations")
            } footer: {
                Text("Phase 1 controls software audio playback only. Device drivers plug into the DeviceControl protocol in SanctuaryCore.")
            }
        }
        .navigationTitle("Devices")
    }
}
