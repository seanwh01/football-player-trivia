//
//  MultiplayerJoinView.swift
//  Football Player Trivia
//
//  Join nearby multiplayer trivia games
//

import SwiftUI
import MultipeerConnectivity

struct MultiplayerJoinView: View {
    @StateObject private var multiplayerManager = MultiplayerManager()
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isNameFieldFocused: Bool
    @Binding var isPresented: Bool
    
    @State private var playerName = ""
    @State private var isBrowsing = false
    @State private var navigateToLobby = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo
                    Image("PigskinGeniusLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .padding(.top, 20)
                    
                    // Title
                    Text("Join Multiplayer Game")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    if !isBrowsing {
                        // Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Name")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            TextField("Enter your name", text: $playerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .focused($isNameFieldFocused)
                        }
                        .padding(.horizontal, 30)
                        .padding(.top, 20)
                        
                        Spacer()
                        
                        // Start Browsing Button
                        Button(action: startBrowsing) {
                            Text("Find Nearby Games")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canStartBrowsing ? Color.green : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!canStartBrowsing)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)
                        
                    } else {
                        // Browsing for hosts
                        VStack(spacing: 16) {
                            if multiplayerManager.availableHosts.isEmpty {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                        .scaleEffect(1.5)
                                    
                                    Text("Searching for nearby games...")
                                        .font(.headline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.top, 8)
                                    
                                    Text("Make sure the host has started their game")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(.top, 60)
                            } else {
                                Text("Available Games")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .padding(.top, 20)
                                
                                ScrollView {
                                    VStack(spacing: 12) {
                                        ForEach(multiplayerManager.availableHosts, id: \.self) { host in
                                            hostButton(host)
                                        }
                                    }
                                    .padding(.horizontal, 30)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Stop Browsing Button
                        Button(action: stopBrowsing) {
                            Text("Cancel")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)
                    }
                }
                
                // Navigation to lobby
                NavigationLink(
                    destination: MultiplayerLobbyView(multiplayerManager: multiplayerManager, isPresented: $isPresented),
                    isActive: $navigateToLobby
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        if isBrowsing {
                            stopBrowsing()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onChange(of: multiplayerManager.connectionState) { state in
            if state == .connected {
                navigateToLobby = true
            }
        }
        .onAppear {
            // Auto-focus name field
            isNameFieldFocused = true
        }
    }
    
    // MARK: - Host Button
    
    private func hostButton(_ host: MCPeerID) -> some View {
        Button(action: {
            joinHost(host)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(multiplayerManager.playerNames[host] ?? host.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(host.displayName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.white.opacity(0.15))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    private var canStartBrowsing: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func startBrowsing() {
        multiplayerManager.startBrowsing(playerName: playerName)
        isBrowsing = true
    }
    
    private func stopBrowsing() {
        multiplayerManager.stopBrowsing()
        isBrowsing = false
    }
    
    private func joinHost(_ host: MCPeerID) {
        multiplayerManager.joinHost(host)
    }
}

#Preview {
    MultiplayerJoinView(isPresented: .constant(true))
}
