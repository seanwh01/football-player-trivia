//
//  MultiplayerGameViewModel.swift
//  Football Player Trivia
//
//  View model for multiplayer game logic and state management
//

import Foundation
import SwiftUI
import MultipeerConnectivity

@MainActor
class MultiplayerGameViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentQuestion: TriviaQuestion?
    @Published var userAnswer = ""
    @Published var hasAnswered = false
    @Published var lastAnswerCorrect = false
    @Published var timeRemaining: TimeInterval = 10.0
    @Published var isTimerRunning = false
    @Published var currentQuestionNumber = 0
    @Published var currentPlayerScore = 0
    @Published var showLeaderboard = false
    @Published var showFinalResults = false
    @Published var isFinalLeaderboard = false
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var leaderboardTimeRemaining: TimeInterval = 5.0
    @Published var showLeaveConfirmation = false
    
    // MARK: - Private Properties
    
    private let multiplayerManager: MultiplayerManager
    private var questionTimer: Timer?
    private var leaderboardTimer: Timer?
    private var answerStartTime: Date?
    private var playerAnswers: [MCPeerID: PlayerAnswer] = [:]
    
    var totalQuestions: Int {
        multiplayerManager.gameSettings?.questionCount ?? 12
    }
    
    // MARK: - Initialization
    
    init(multiplayerManager: MultiplayerManager) {
        self.multiplayerManager = multiplayerManager
    }
    
    // MARK: - Setup
    
    func setupCallbacks() {
        multiplayerManager.onQuestionReceived = { [weak self] question in
            self?.receiveQuestion(question)
        }
        
        multiplayerManager.onAnswerReceived = { [weak self] playerID, answer, isCorrect, responseTime in
            self?.receiveAnswer(from: playerID, answer: answer, isCorrect: isCorrect, responseTime: responseTime)
        }
        
        multiplayerManager.onNextQuestion = { [weak self] in
            self?.handleNextQuestion()
        }
        
        multiplayerManager.onLeaderboardUpdate = { [weak self] entries in
            self?.updateLeaderboard(entries)
        }
        
        multiplayerManager.onGameEnd = { [weak self] in
            self?.endGame()
        }
    }
    
    // MARK: - Question Management (Host)
    
    func loadNextQuestion() {
        guard multiplayerManager.isHost, let settings = multiplayerManager.gameSettings else { return }
        
        currentQuestionNumber += 1
        
        // Check if game is over
        if currentQuestionNumber > totalQuestions {
            endGame()
            multiplayerManager.broadcastGameEnd()
            return
        }
        
        // Generate random question based on settings
        let question = generateQuestion(from: settings)
        currentQuestion = question
        
        // Broadcast to all players
        multiplayerManager.broadcastQuestion(question)
        
        // Reset for new question
        resetForNewQuestion()
        
        // Start timer
        startQuestionTimer()
    }
    
    private func generateQuestion(from settings: MultiplayerGameSettings) -> TriviaQuestion {
        // Randomly select from settings
        let position = settings.positions.randomElement() ?? "QB"
        let team = settings.teams.randomElement() ?? "KC"
        let year = Int.random(in: settings.yearFrom...settings.yearTo)
        
        // For demo, generate sample player names
        // In production, this would query your database
        let firstNames = ["Patrick", "Josh", "Lamar", "Joe", "Travis", "Tyreek", "Stefon", "Justin"]
        let lastNames = ["Mahomes", "Allen", "Jackson", "Burrow", "Kelce", "Hill", "Diggs", "Jefferson"]
        
        let firstName = firstNames.randomElement() ?? "John"
        let lastName = lastNames.randomElement() ?? "Doe"
        
        return TriviaQuestion(
            playerFirstName: firstName,
            playerLastName: lastName,
            position: position,
            team: team,
            year: year
        )
    }
    
    // MARK: - Question Management (Player)
    
    private func receiveQuestion(_ question: TriviaQuestion) {
        currentQuestion = question
        currentQuestionNumber += 1
        resetForNewQuestion()
        startQuestionTimer()
    }
    
    private func handleNextQuestion() {
        showLeaderboard = false
        
        if multiplayerManager.isHost {
            loadNextQuestion()
        }
    }
    
    // MARK: - Answer Submission
    
    func submitAnswer() {
        guard !hasAnswered, let question = currentQuestion else { return }
        
        stopQuestionTimer()
        hasAnswered = true
        
        let responseTime = Date().timeIntervalSince(answerStartTime ?? Date())
        
        // Check if answer is correct (simple string comparison for demo)
        // In production, use your Firebase validation
        let correctAnswer = question.fullPlayerName.lowercased()
        let playerAnswer = userAnswer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isCorrect = playerAnswer == correctAnswer || 
                       playerAnswer == question.playerFirstName.lowercased() ||
                       playerAnswer == question.playerLastName.lowercased()
        
        lastAnswerCorrect = isCorrect
        
        if isCorrect {
            // Award points based on speed (10 points max, decreases with time)
            let points = max(1, 10 - Int(responseTime))
            currentPlayerScore += points
        }
        
        // Send to host
        multiplayerManager.submitAnswer(userAnswer, isCorrect: isCorrect, responseTime: responseTime)
    }
    
    private func receiveAnswer(from playerID: MCPeerID, answer: String, isCorrect: Bool, responseTime: TimeInterval) {
        guard multiplayerManager.isHost else { return }
        
        let points = isCorrect ? max(1, 10 - Int(responseTime)) : 0
        
        playerAnswers[playerID] = PlayerAnswer(
            answer: answer,
            isCorrect: isCorrect,
            responseTime: responseTime,
            points: points
        )
        
        // Check if all players have answered
        let totalPlayers = 1 + multiplayerManager.connectedPeers.count // host + peers
        if playerAnswers.count == totalPlayers {
            showLeaderboardAfterAllAnswered()
        }
    }
    
    // MARK: - Timer Management
    
    private func startQuestionTimer() {
        timeRemaining = 10.0
        isTimerRunning = true
        answerStartTime = Date()
        
        questionTimer?.invalidate()
        questionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.timeRemaining -= 0.1
                
                if self.timeRemaining <= 0 {
                    self.handleTimeExpired()
                }
            }
        }
    }
    
    private func stopQuestionTimer() {
        questionTimer?.invalidate()
        questionTimer = nil
        isTimerRunning = false
    }
    
    private func handleTimeExpired() {
        stopQuestionTimer()
        
        if !hasAnswered {
            hasAnswered = true
            lastAnswerCorrect = false
            
            // Submit as incorrect with max time
            multiplayerManager.submitAnswer("", isCorrect: false, responseTime: 10.0)
        }
    }
    
    // MARK: - Leaderboard
    
    private func showLeaderboardAfterAllAnswered() {
        guard multiplayerManager.isHost else { return }
        
        stopQuestionTimer()
        
        // Calculate leaderboard
        let entries = calculateLeaderboard()
        leaderboard = entries
        
        // Broadcast to all players
        multiplayerManager.broadcastLeaderboard(entries)
        
        // Show leaderboard
        showLeaderboard = true
        isFinalLeaderboard = currentQuestionNumber >= totalQuestions
        
        if !isFinalLeaderboard {
            startLeaderboardTimer()
        }
    }
    
    private func calculateLeaderboard() -> [LeaderboardEntry] {
        var scores: [String: (score: Int, totalTime: TimeInterval, answerCount: Int)] = [:]
        
        // Add host's score
        let hostName = multiplayerManager.playerName
        scores[hostName] = (currentPlayerScore, 0, 0)
        
        // Add peer scores (would need to track across all questions in production)
        for (peerID, answer) in playerAnswers {
            if let playerName = multiplayerManager.playerNames[peerID] {
                if var existing = scores[playerName] {
                    existing.score += answer.points
                    existing.totalTime += answer.responseTime
                    existing.answerCount += 1
                    scores[playerName] = existing
                } else {
                    scores[playerName] = (answer.points, answer.responseTime, 1)
                }
            }
        }
        
        // Convert to leaderboard entries
        let entries = scores.map { name, data in
            LeaderboardEntry(
                id: name,
                playerName: name,
                score: data.score,
                averageResponseTime: data.answerCount > 0 ? data.totalTime / Double(data.answerCount) : 0
            )
        }
        .sorted { $0.score > $1.score || ($0.score == $1.score && $0.averageResponseTime < $1.averageResponseTime) }
        
        return entries
    }
    
    private func updateLeaderboard(_ entries: [LeaderboardEntry]) {
        leaderboard = entries
        showLeaderboard = true
        isFinalLeaderboard = currentQuestionNumber >= totalQuestions
        
        if !isFinalLeaderboard && !multiplayerManager.isHost {
            startLeaderboardTimer()
        }
    }
    
    private func startLeaderboardTimer() {
        leaderboardTimeRemaining = 5.0
        
        leaderboardTimer?.invalidate()
        leaderboardTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.leaderboardTimeRemaining -= 0.1
                
                if self.leaderboardTimeRemaining <= 0 {
                    self.hideLeaderboard()
                }
            }
        }
    }
    
    private func hideLeaderboard() {
        leaderboardTimer?.invalidate()
        leaderboardTimer = nil
        showLeaderboard = false
        
        if multiplayerManager.isHost {
            multiplayerManager.broadcastNextQuestion()
            loadNextQuestion()
        }
    }
    
    // MARK: - Game End
    
    private func endGame() {
        stopQuestionTimer()
        leaderboardTimer?.invalidate()
        
        showLeaderboard = false
        showFinalResults = true
        isFinalLeaderboard = true
        
        if multiplayerManager.isHost && leaderboard.isEmpty {
            leaderboard = calculateLeaderboard()
        }
    }
    
    // MARK: - Reset
    
    private func resetForNewQuestion() {
        userAnswer = ""
        hasAnswered = false
        lastAnswerCorrect = false
        timeRemaining = 10.0
        playerAnswers.removeAll()
    }
    
    deinit {
        questionTimer?.invalidate()
        leaderboardTimer?.invalidate()
    }
}

// MARK: - Supporting Types

struct PlayerAnswer {
    let answer: String
    let isCorrect: Bool
    let responseTime: TimeInterval
    let points: Int
}
