//
//  MultiplayerGameView.swift
//  Football Player Trivia
//
//  Main multiplayer game view with 20-second timer and live scoring
//

import SwiftUI

struct MultiplayerGameView: View {
    @ObservedObject var multiplayerManager: MultiplayerManager
    @StateObject private var viewModel: MultiplayerGameViewModel
    @Environment(\.presentationMode) var presentationMode
    @Binding var isPresented: Bool
    @State private var adRefreshTrigger = 0
    
    init(multiplayerManager: MultiplayerManager, isPresented: Binding<Bool>) {
        self.multiplayerManager = multiplayerManager
        self._isPresented = isPresented
        _viewModel = StateObject(wrappedValue: MultiplayerGameViewModel(multiplayerManager: multiplayerManager))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                // Main Content
                if viewModel.showLeaderboard {
                    leaderboardView
                } else if viewModel.showFinalResults {
                    finalResultsView
                } else if viewModel.currentQuestion != nil {
                    questionView
                }
                
                // Banner Ad
                BannerAdView(
                    adUnitID: AdMobManager.shared.getBannerAdUnitID(),
                    refreshTrigger: $adRefreshTrigger
                )
                .frame(height: 50)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Leave Game?", isPresented: $viewModel.showLeaveConfirmation) {
            Button("Leave", role: .destructive) {
                leaveGame()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to leave the game?")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    viewModel.showLeaveConfirmation = true
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
            viewModel.setupCallbacks()
            if multiplayerManager.isHost {
                // Small delay to ensure all players have set up callbacks
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.loadNextQuestion()
                }
            }
        }
        .alert("Host Disconnected", isPresented: $viewModel.hostDisconnected) {
            Button("OK") {
                leaveGame()
            }
        } message: {
            Text("The host has left the game. Returning to menu.")
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if viewModel.currentQuestionNumber > 0 || viewModel.currentQuestion != nil {
                    Text("Question \(viewModel.currentQuestionNumber)/\(viewModel.totalQuestions)")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    Text("Starting...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text("Score: \(viewModel.currentPlayerScore)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            if viewModel.isTimerRunning {
                timerCircle
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }
    
    private var timerCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 4)
                .frame(width: 60, height: 60)
            
            Circle()
                .trim(from: 0, to: CGFloat(viewModel.timeRemaining) / 20.0)
                .stroke(
                    viewModel.timeRemaining > 10 ? Color.green : Color.red,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: viewModel.timeRemaining)
            
            Text("\(Int(ceil(viewModel.timeRemaining)))")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Host Spin View
    
    private var hostSpinView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("Get ready to spin for the next player!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                viewModel.loadNextQuestion()
            }) {
                Text("Spin for Player")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Question View
    
    private var questionView: some View {
        VStack(spacing: 24) {
            // Logo
            Image("PigskinGeniusLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .padding(.top, 10)
            
            Spacer()
            
            if let question = viewModel.currentQuestion {
                // Question Text
                VStack(spacing: 12) {
                    Text(question.questionText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                    
                    HStack(spacing: 8) {
                        Text(question.position)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        Text(question.team)
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        Text(String(question.year))
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                
                // Answer Input or Result
                if viewModel.isValidating {
                    // Show validating state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.orange)
                        
                        Text("Validating answer...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    .padding(.vertical, 40)
                } else if !viewModel.hasAnswered {
                    VStack(spacing: 16) {
                        TextField("Enter player name", text: $viewModel.userAnswer)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disabled(viewModel.hasAnswered || !viewModel.isTimerRunning)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            viewModel.submitAnswer(viewModel.userAnswer)
                        }) {
                            Text("Submit Answer")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSubmitAnswer ? Color.green : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!canSubmitAnswer)
                        .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.lastAnswerCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(viewModel.lastAnswerCorrect ? .green : .red)
                        
                        Text(viewModel.lastAnswerCorrect ? "Correct!" : "Incorrect")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        // Show all correct answers if there are multiple
                        if viewModel.correctPlayers.count > 1 {
                            VStack(spacing: 8) {
                                Text("The correct answers include:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.top, 8)
                                
                                ForEach(viewModel.correctPlayers, id: \.playerId) { player in
                                    Text("\(player.firstName) \(player.lastName)")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.orange)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        } else if let firstPlayer = viewModel.correctPlayers.first {
                            VStack(spacing: 4) {
                                Text("Answer:")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("\(firstPlayer.firstName) \(firstPlayer.lastName)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        }
                        
                        if !multiplayerManager.isHost {
                            Text("Waiting for all players...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 8)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Leaderboard View
    
    private var leaderboardView: some View {
        VStack(spacing: 24) {
            // Logo
            Image("PigskinGeniusLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .padding(.top, 20)
            
            Text(viewModel.isFinalLeaderboard ? "Final Scores" : "Leaderboard")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(entry: entry, rank: index + 1)
                    }
                }
                .padding(.horizontal, 30)
            }
            
            if !viewModel.isFinalLeaderboard {
                Text("Next question in \(Int(ceil(viewModel.leaderboardTimeRemaining)))...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 20)
            }
        }
    }
    
    private func leaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor(rank))
                    .frame(width: 40, height: 40)
                
                Text("\(rank)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Player Name
            Text(entry.playerName)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            // Score
            Text("\(entry.score) pts")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
        }
        .padding()
        .background(rank <= 3 ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
        .cornerRadius(12)
    }
    
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color.yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return Color.white.opacity(0.3)
        }
    }
    
    // MARK: - Final Results View
    
    private var finalResultsView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            if let winner = viewModel.leaderboard.first {
                VStack(spacing: 16) {
                    Text("🏆")
                        .font(.system(size: 80))
                    
                    Text("WINNER!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.orange)
                    
                    Text(winner.playerName)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("\(winner.score) points")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            Button(action: {
                leaveGame()
            }) {
                Text("Back to Menu")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Computed Properties
    
    private var canSubmitAnswer: Bool {
        !viewModel.userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.hasAnswered &&
        viewModel.isTimerRunning
    }
    
    // MARK: - Actions
    
    private func leaveGame() {
        if multiplayerManager.isHost {
            multiplayerManager.stopHosting()
        } else {
            multiplayerManager.stopBrowsing()
        }
        // Dismiss entire navigation stack back to ContentView
        isPresented = false
    }
}
