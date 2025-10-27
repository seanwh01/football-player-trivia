//
//  MultiplayerLobbyView.swift
//  Football Player Trivia
//
//  Lobby view showing connected players before game starts
//

import SwiftUI

struct MultiplayerLobbyView: View {
    @ObservedObject var multiplayerManager: MultiplayerManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var navigateToGame = false
    @State private var showHostDisconnectedAlert = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Title
                Text(multiplayerManager.isHost ? "Game Lobby" : "Waiting for Host")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                // Game Settings (Host only)
                if multiplayerManager.isHost, let settings = multiplayerManager.gameSettings {
                    VStack(spacing: 12) {
                        Text("Game Settings")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        VStack(spacing: 8) {
                            settingRow(title: "Questions", value: "\(settings.questionCount)")
                            settingRow(title: "Years", value: "\(settings.yearFrom)-\(settings.yearTo)")
                            settingRow(title: "Positions", value: "\(settings.positions.count) selected")
                            settingRow(title: "Teams", value: "\(settings.teams.count) selected")
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 30)
                }
                
                // Connected Players
                VStack(spacing: 16) {
                    Text("Players (\(allPlayers.count)/8)")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(allPlayers.enumerated()), id: \.element) { index, player in
                                playerRow(name: player, index: index)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                }
                
                Spacer()
                
                // Host Controls
                if multiplayerManager.isHost {
                    VStack(spacing: 12) {
                        Text("Waiting for players to join...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button(action: startGame) {
                            Text("Start Game")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(canStartGame ? Color.green : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!canStartGame)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                } else {
                    Text("Waiting for host to start the game...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.bottom, 40)
                }
            }
            
            // Navigation to game
            NavigationLink(
                destination: MultiplayerGameView(multiplayerManager: multiplayerManager),
                isActive: $navigateToGame
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if multiplayerManager.isHost {
                        multiplayerManager.stopHosting()
                    } else {
                        multiplayerManager.stopBrowsing()
                    }
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Leave")
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            setupGameCallbacks()
        }
        .alert("Host Disconnected", isPresented: $showHostDisconnectedAlert) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("The host has left the lobby. Returning to menu.")
        }
    }
    
    // MARK: - Helper Views
    
    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .font(.subheadline)
    }
    
    private func playerRow(name: String, index: Int) -> some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)
            
            Text(name)
                .font(.headline)
                .foregroundColor(.white)
            
            if index == 0 {
                Text("(Host)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Computed Properties
    
    private var allPlayers: [String] {
        var players: [String] = []
        
        // Add host first
        players.append(multiplayerManager.playerName)
        
        // Add connected peers
        for peer in multiplayerManager.connectedPeers {
            if let name = multiplayerManager.playerNames[peer] {
                players.append(name)
            }
        }
        
        return players
    }
    
    private var canStartGame: Bool {
        // Need at least 2 players (host + 1 other)
        allPlayers.count >= 2
    }
    
    // MARK: - Actions
    
    private func setupGameCallbacks() {
        multiplayerManager.onGameStart = {
            navigateToGame = true
        }
        
        multiplayerManager.onHostDisconnected = {
            showHostDisconnectedAlert = true
        }
    }
    
    private func startGame() {
        multiplayerManager.startGame()
        navigateToGame = true
    }
}

#Preview {
    let manager = MultiplayerManager()
    manager.playerName = "Test Player"
    manager.isHost = true
    manager.gameSettings = MultiplayerGameSettings(
        positions: ["QB", "RB"],
        teams: ["KC", "BUF"],
        yearFrom: 2023,
        yearTo: 2024,
        questionCount: 12
    )
    
    return NavigationView {
        MultiplayerLobbyView(multiplayerManager: manager)
    }
}
