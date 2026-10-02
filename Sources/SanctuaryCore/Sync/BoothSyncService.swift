import Combine
import Foundation
import MultipeerConnectivity

/// MultipeerConnectivity wrapper syncing the Mac hub and the iPad remote.
///
/// Phase 1 design: BOTH devices advertise and browse simultaneously, so either
/// side finds the other with zero configuration. Invitations are auto-accepted.
/// The iPad (iOS) is the "follower": on connect it asks for a full state
/// snapshot; the Mac (macOS) is the source of truth and answers.
public final class BoothSyncService: NSObject, ObservableObject {
    /// Bonjour service type. Must be <= 15 chars, lowercase ASCII + hyphen.
    public static let serviceType = "sanctuary-av"

    public enum ConnectionState: String {
        case idle
        case searching
        case connected

        public var displayName: String { rawValue.capitalized }
    }

    @Published public private(set) var connectionState: ConnectionState = .idle
    @Published public private(set) var connectedPeerNames: [String] = []

    /// Called on the main queue for every decoded message.
    public var onMessageReceived: ((SyncMessage, MCPeerID) -> Void)?
    /// Called on the main queue when a peer finishes connecting.
    public var onPeerConnected: ((MCPeerID) -> Void)?

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    public override init() {
        let baseName: String = {
            #if os(macOS)
            return "Booth Mac"
            #else
            return "Booth iPad"
            #endif
        }()
        // Short random suffix avoids display-name collisions on the booth LAN.
        let displayName = "\(baseName)-\(String(UUID().uuidString.prefix(4)))"
        self.peerID = MCPeerID(displayName: displayName)
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["app": "sanctuary", "v": "1"],
            serviceType: Self.serviceType
        )
        self.browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.serviceType
        )
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    deinit {
        stop()
    }

    public func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        DispatchQueue.main.async { self.connectionState = .searching }
    }

    public func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        DispatchQueue.main.async {
            self.connectionState = .idle
            self.connectedPeerNames = []
        }
    }

    /// Best-effort send to all connected peers. No-ops when nobody is connected.
    public func send(_ message: SyncMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            let data = try message.encoded()
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[BoothSync] send failed: \(error)")
        }
    }

    private func refreshConnectionState() {
        let names = session.connectedPeers.map(\.displayName)
        DispatchQueue.main.async {
            self.connectedPeerNames = names
            self.connectionState = names.isEmpty ? .searching : .connected
        }
    }
}

// MARK: - MCSessionDelegate

extension BoothSyncService: MCSessionDelegate {
    public func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        refreshConnectionState()
        if state == .connected {
            DispatchQueue.main.async { self.onPeerConnected?(peerID) }
        }
    }

    public func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        do {
            let message = try SyncMessage.decoded(from: data)
            DispatchQueue.main.async {
                self.onMessageReceived?(message, peerID)
            }
        } catch {
            print("[BoothSync] decode failed: \(error)")
        }
    }

    // Unused required delegate stubs.
    public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

// MARK: - Advertiser / Browser delegates

extension BoothSyncService: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Phase 1: booth LAN is trusted; auto-accept.
        invitationHandler(true, session)
    }
}

extension BoothSyncService: MCNearbyServiceBrowserDelegate {
    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    public func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {}
}
