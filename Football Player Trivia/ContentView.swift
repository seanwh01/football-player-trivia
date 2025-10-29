//
//  ContentView.swift
//  Football Trivia
//
//  Home screen with navigation to game and settings
//

import SwiftUI
import AVFoundation
import AppTrackingTransparency
import AdSupport

struct ContentView: View {
    @StateObject private var gameSettings = GameSettings()
    @State private var audioPlayer: AVAudioPlayer?
    @State private var hasPlayedSound = false
    @State private var hasResetChallenge = false
    @State private var isLoadingUpcomingGame = false
    @State private var showGameChallengeAlert = false
    @State private var gameChallengeMessage = ""
    @State private var navigateToGame = false
    @State private var showNoFavoriteTeamAlert = false
    @State private var navigateToSettings = false
    @State private var showMultiplayerMenu = false
    @State private var showMultiplayerHost = false
    @State private var showMultiplayerJoin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - Football field image
                GeometryReader { geometry in
                    Image("FootballFieldBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(Color.black.opacity(0.4))
                }
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // App Icon/Logo
                    Image("PigskinGeniusLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 5)
                    
                    // Tagline
                    Text("Test your NFL player knowledge!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                        .padding(.top, 10)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Upcoming Game Challenge Button
                        Button(action: {
                            loadUpcomingGameChallenge()
                        }) {
                            VStack(spacing: 6) {
                                HStack {
                                    Image(systemName: isLoadingUpcomingGame ? "arrow.triangle.2.circlepath" : "calendar.badge.clock")
                                        .rotationEffect(isLoadingUpcomingGame ? .degrees(360) : .degrees(0))
                                        .animation(isLoadingUpcomingGame ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoadingUpcomingGame)
                                    Text(isLoadingUpcomingGame ? "Loading..." : "Upcoming Game Challenge")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Text("Pre-load the next game for your favorite team")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isLoadingUpcomingGame)
                        
                        // Multiplayer Head to Head Button
                        Button(action: {
                            showMultiplayerMenu = true
                        }) {
                            VStack(spacing: 6) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("Head to Head Trivia Game")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Text("Play multiplayer trivia with nearby friends")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                        
                        // Single Player Trivia Game Button
                        NavigationLink(destination: TriviaGameView(settings: gameSettings)) {
                            VStack(spacing: 6) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                    Text("Single Player Trivia Game")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                Text("Trivia questions based on Settings page")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }
                
                // Hidden NavigationLinks for programmatic navigation
                NavigationLink(destination: TriviaGameView(settings: gameSettings), isActive: $navigateToGame) {
                    EmptyView()
                }
                .hidden()
                
                NavigationLink(destination: SettingsView(settings: gameSettings), isActive: $navigateToSettings) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(settings: gameSettings)) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                requestTrackingPermission()
                playWhistleSoundOnce()
                resetChallengeState()
            }
        }
        .navigationViewStyle(.stack)
        .alert("No Favorite Team", isPresented: $showNoFavoriteTeamAlert) {
            Button("Go to Settings", role: .none) {
                navigateToSettings = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please select a favorite team in Settings before using Upcoming Game Challenge.")
        }
        .alert("Upcoming Game Challenge", isPresented: $showGameChallengeAlert) {
            Button("OK", role: .cancel) {
                if gameChallengeMessage.contains("Challenge loaded") {
                    navigateToGame = true
                }
            }
        } message: {
            Text(gameChallengeMessage)
        }
        .confirmationDialog("Multiplayer Mode", isPresented: $showMultiplayerMenu) {
            Button("Host Game") {
                showMultiplayerHost = true
            }
            Button("Join Nearby Game") {
                showMultiplayerJoin = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose whether to host a game or join a nearby game")
        }
        .fullScreenCover(isPresented: $showMultiplayerHost) {
            MultiplayerHostSetupView(settings: gameSettings, isPresented: $showMultiplayerHost)
        }
        .fullScreenCover(isPresented: $showMultiplayerJoin) {
            MultiplayerJoinView(isPresented: $showMultiplayerJoin)
        }
    }
    
    private func resetChallengeState() {
        // Only reset once per app session, not every time ContentView appears
        guard !hasResetChallenge else {
            return
        }
        
        // Clear any challenge game state from previous session
        // This ensures the app starts fresh without an active challenge
        // Users must go to Settings -> Upcoming Game Challenge to start a new game
        if gameSettings.selectedTeams.count == 2 {
            print("🔄 Clearing previous challenge state - resetting to all teams")
            gameSettings.selectedTeams = Set(gameSettings.allTeams)
        }
        
        hasResetChallenge = true
    }
    
    private func playWhistleSoundOnce() {
        guard gameSettings.soundEnabled && !hasPlayedSound else {
            return
        }
        
        guard let soundURL = Bundle.main.url(forResource: "referee-whistle", withExtension: "mp3") else {
            print("ℹ️ referee-whistle.mp3 not found - skipping sound")
            hasPlayedSound = true // Mark as played so we don't keep trying
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            hasPlayedSound = true
            print("🔊 Playing referee whistle sound!")
        } catch {
            print("❌ Failed to play sound: \(error.localizedDescription)")
        }
    }
    
    private func loadUpcomingGameChallenge() {
        // Check if favorite team is selected
        guard !gameSettings.favoriteTeam.isEmpty else {
            showNoFavoriteTeamAlert = true
            return
        }
        
        isLoadingUpcomingGame = true
        gameChallengeMessage = ""
        
        NFLScheduleService.shared.getNextGame(for: gameSettings.favoriteTeam) { result in
            DispatchQueue.main.async {
                self.isLoadingUpcomingGame = false
                
                switch result {
                case .success(let game):
                    if let game = game {
                        // Pre-set the teams for the upcoming game
                        let currentYear = Calendar.current.component(.year, from: Date())
                        
                        // Set year to current year
                        self.gameSettings.yearFrom = currentYear
                        self.gameSettings.yearTo = currentYear
                        
                        // Enable all positions for the challenge
                        self.gameSettings.selectedPositions = Set(self.gameSettings.allPositions)
                        
                        // Set only the two teams playing in the game
                        self.gameSettings.selectedTeams = Set([game.homeTeam, game.awayTeam])
                        
                        // Format the date
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        let dateString = dateFormatter.string(from: game.date)
                        
                        self.gameChallengeMessage = "🏈 Challenge loaded!\n\n\(game.awayTeam) @ \(game.homeTeam)\n\(dateString)\n\nSettings configured for \(currentYear) with all positions enabled for both teams."
                        self.showGameChallengeAlert = true
                        
                    } else {
                        self.gameChallengeMessage = "No upcoming game found for \(self.gameSettings.favoriteTeam).\n\nThis could mean:\n• The season hasn't started\n• Your team's season is over\n• No games are scheduled"
                        self.showGameChallengeAlert = true
                    }
                    
                case .failure(let error):
                    self.gameChallengeMessage = "❌ Failed to load game schedule.\n\n\(error.localizedDescription)"
                    self.showGameChallengeAlert = true
                }
            }
        }
    }
    
    private func requestTrackingPermission() {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        print("📊 Current tracking status: \(currentStatus.rawValue)")
        
        guard currentStatus == .notDetermined else {
            print("ℹ️ Tracking already determined, skipping request")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("🔔 Requesting tracking authorization...")
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("✅ Tracking authorized - AdMob can use IDFA")
                case .denied:
                    print("⚠️ Tracking denied - AdMob will use limited ads")
                case .notDetermined:
                    print("⚠️ Tracking not determined")
                case .restricted:
                    print("⚠️ Tracking restricted")
                @unknown default:
                    print("⚠️ Unknown tracking status")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
