//
//  MultiplayerManager.swift
//  Football Player Trivia
//
//  Manages Multipeer Connectivity for multiplayer trivia games
//

import Foundation
import MultipeerConnectivity
import Combine

@MainActor
class MultiplayerManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var isHost = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var playerNames: [MCPeerID: String] = [:]
    @Published var availableHosts: [MCPeerID] = []
    @Published var connectionState: ConnectionState = .disconnected
    
    // MARK: - Multipeer Properties
    
    private let serviceType = "nfl-trivia"
    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    // MARK: - Game State
    
    var playerName: String = ""
    var gameSettings: MultiplayerGameSettings?
    var hostPeerID: MCPeerID?
    
    var hostName: String? {
        guard let hostID = hostPeerID else { return nil }
        return playerNames[hostID]
    }
    
    // MARK: - Message Handlers
    
    var onQuestionReceived: ((TriviaQuestion) -> Void)?
    var onAnswerReceived: ((String, String, Bool, TimeInterval) -> Void)?
    var onGameStart: (() -> Void)?
    var onNextQuestion: (() -> Void)?
    var onGameEnd: (() -> Void)?
    var onLeaderboardUpdate: (([LeaderboardEntry]) -> Void)?
    var onHostDisconnected: (() -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        // Create unique peer ID for this device
        let deviceName = UIDevice.current.name
        self.peerID = MCPeerID(displayName: deviceName)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        
        super.init()
        
        session.delegate = self
    }
    
    // MARK: - Host Methods
    
    func startHosting(playerName: String, settings: MultiplayerGameSettings) {
        self.playerName = playerName
        self.gameSettings = settings
        self.isHost = true
        
        // Add self to player names
        playerNames[peerID] = playerName
        
        // Start advertising
        let discoveryInfo = ["hostName": playerName]
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        connectionState = .hosting
        print("🎮 Started hosting as: \(playerName)")
    }
    
    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session.disconnect()
        reset()
    }
    
    func startGame() {
        guard isHost, let settings = gameSettings else { return }
        
        // Broadcast game start with settings
        let message = GameMessage.gameStart(settings: settings)
        sendToAllPeers(message)
        
        // Notify local host
        onGameStart?()
    }
    
    func broadcastQuestion(_ question: TriviaQuestion) {
        guard isHost else { return }
        
        let message = GameMessage.question(question)
        sendToAllPeers(message)
    }
    
    func broadcastNextQuestion() {
        guard isHost else { return }
        
        let message = GameMessage.nextQuestion
        sendToAllPeers(message)
    }
    
    func broadcastLeaderboard(_ entries: [LeaderboardEntry]) {
        guard isHost else { return }
        
        let message = GameMessage.leaderboard(entries)
        sendToAllPeers(message)
    }
    
    func broadcastGameEnd() {
        guard isHost else { return }
        
        let message = GameMessage.gameEnd
        sendToAllPeers(message)
    }
    
    // MARK: - Join Methods
    
    func startBrowsing(playerName: String) {
        self.playerName = playerName
        self.isHost = false
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        connectionState = .browsing
        print("🔍 Started browsing as: \(playerName)")
    }
    
    func joinHost(_ host: MCPeerID) {
        guard let browser = browser else { return }
        
        // Track the host peer ID
        hostPeerID = host
        
        // Send invitation with player name
        let context = playerName.data(using: .utf8)
        browser.invitePeer(host, to: session, withContext: context, timeout: 30)
        
        connectionState = .connecting
        print("📡 Joining host: \(host.displayName)")
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        reset()
    }
    
    // MARK: - Player Methods
    
    func submitAnswer(_ answer: String, isCorrect: Bool, responseTime: TimeInterval) {
        let message = GameMessage.answer(playerID: playerName, answer: answer, isCorrect: isCorrect, responseTime: responseTime)
        
        if isHost {
            // Host processes own answer
            onAnswerReceived?(playerName, answer, isCorrect, responseTime)
        } else {
            // Send to host
            sendToHost(message)
        }
    }
    
    // MARK: - Messaging
    
    private func sendToAllPeers(_ message: GameMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("❌ Error sending message: \(error)")
        }
    }
    
    private func sendToHost(_ message: GameMessage) {
        guard !isHost, !session.connectedPeers.isEmpty else { return }
        
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("❌ Error sending to host: \(error)")
        }
    }
    
    private func handleReceivedMessage(_ data: Data, from peer: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(GameMessage.self, from: data)
            
            Task { @MainActor in
                switch message {
                case .gameStart(let settings):
                    self.gameSettings = settings
                    self.onGameStart?()
                    
                case .question(let question):
                    self.onQuestionReceived?(question)
                    
                case .answer(let playerID, let answer, let isCorrect, let responseTime):
                    if isHost {
                        self.onAnswerReceived?(playerID, answer, isCorrect, responseTime)
                    }
                    
                case .nextQuestion:
                    self.onNextQuestion?()
                    
                case .leaderboard(let entries):
                    self.onLeaderboardUpdate?(entries)
                    
                case .gameEnd:
                    self.onGameEnd?()
                }
            }
        } catch {
            print("❌ Error decoding message: \(error)")
        }
    }
    
    // MARK: - Utility
    
    private func reset() {
        isHost = false
        connectedPeers.removeAll()
        playerNames.removeAll()
        availableHosts.removeAll()
        connectionState = .disconnected
        gameSettings = nil
    }
}

// MARK: - MCSessionDelegate

extension MultiplayerManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                print("✅ Connected to: \(peerID.displayName)")
                if !connectedPeers.contains(peerID) {
                    connectedPeers.append(peerID)
                }
                connectionState = .connected
                
            case .connecting:
                print("🔄 Connecting to: \(peerID.displayName)")
                connectionState = .connecting
                
            case .notConnected:
                print("❌ Disconnected from: \(peerID.displayName)")
                connectedPeers.removeAll { $0 == peerID }
                playerNames.removeValue(forKey: peerID)
                
                // Check if the host disconnected
                if !isHost && peerID == hostPeerID {
                    print("⚠️ Host disconnected - ending game")
                    onHostDisconnected?()
                }
                
                if connectedPeers.isEmpty && !isHost {
                    connectionState = .disconnected
                }
                
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            handleReceivedMessage(data, from: peerID)
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }
    
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }
    
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultiplayerManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Extract player name from context
            if let context = context, let playerName = String(data: context, encoding: .utf8) {
                playerNames[peerID] = playerName
                print("📥 Invitation from: \(playerName)")
            }
            
            // Auto-accept (max 7 players + host = 8 total)
            if connectedPeers.count < 7 {
                invitationHandler(true, session)
            } else {
                invitationHandler(false, nil)
                print("⚠️ Game full, rejected: \(peerID.displayName)")
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultiplayerManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            if let hostName = info?["hostName"] {
                playerNames[peerID] = hostName
                print("🔍 Found host: \(hostName)")
            }
            
            if !availableHosts.contains(peerID) {
                availableHosts.append(peerID)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            availableHosts.removeAll { $0 == peerID }
            print("📡 Lost host: \(peerID.displayName)")
        }
    }
}

// MARK: - Supporting Types

enum ConnectionState {
    case disconnected
    case browsing
    case hosting
    case connecting
    case connected
}

struct MultiplayerGameSettings: Codable {
    let positions: [String]
    let teams: [String]
    let yearFrom: Int
    let yearTo: Int
    let questionCount: Int
    let timeToAnswer: Int // 30, 60, or 90 seconds
    let hintsEnabled: Bool
    let moreObviousHintsEnabled: Bool
}

enum GameMessage: Codable {
    case gameStart(settings: MultiplayerGameSettings)
    case question(TriviaQuestion)
    case answer(playerID: String, answer: String, isCorrect: Bool, responseTime: TimeInterval)
    case nextQuestion
    case leaderboard([LeaderboardEntry])
    case gameEnd
}

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let playerName: String
    let score: Int
    let averageResponseTime: TimeInterval
    
    var rank: Int = 0
}

