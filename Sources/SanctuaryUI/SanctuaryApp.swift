import SwiftUI
import SanctuaryCore

/// App entry point.
///
/// NOTE for the Xcode project: the Xcode app target contains NO @main of its
/// own — this struct, compiled inside the SanctuaryUI Swift package, IS the
/// entry point. The app target only needs to link SanctuaryUI (which pulls in
/// SanctuaryCore) and provide an Info.plist + signing. See README.md.
@main
public struct SanctuaryApp: App {
    @StateObject private var store = BoothStore()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(store)
        }
    }
}
