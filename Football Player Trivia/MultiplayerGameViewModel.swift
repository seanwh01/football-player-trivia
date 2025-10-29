//
//  MultiplayerGameViewModel.swift
//  Football Player Trivia
//
//  View model for multiplayer game logic and state management
//

import Foundation
import SwiftUI
import Combine
import MultipeerConnectivity

@MainActor
class MultiplayerGameViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentQuestion: TriviaQuestion?
    @Published var userAnswer = ""
    @Published var hasAnswered = false
    @Published var isValidating = false
    @Published var lastAnswerCorrect = false
    @Published var correctPlayers: [Player] = []
    @Published var currentQuestionPoints = 0
    @Published var timeRemaining: TimeInterval = 30.0
    @Published var isTimerRunning = false
    @Published var currentQuestionNumber = 0
    @Published var currentPlayerScore = 0
    @Published var showLeaderboard = false
    @Published var showFinalResults = false
    @Published var isFinalLeaderboard = false
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var leaderboardTimeRemaining: TimeInterval = 5.0
    @Published var answerDisplayTimeRemaining: TimeInterval = 8.0
    @Published var showLeaveConfirmation = false
    @Published var hostDisconnected = false
    @Published var showHintSheet = false
    @Published var generalHint = ""
    @Published var moreObviousHint = ""
    @Published var hasUsedHint = false
    
    // MARK: - Private Properties
    
    private let multiplayerManager: MultiplayerManager
    private var questionTimer: Timer?
    private var leaderboardTimer: Timer?
    private var answerDisplayTimer: Timer?
    private var answerStartTime: Date?
    private var playerAnswers: [String: PlayerAnswer] = [:] // Current question only
    private var cumulativeScores: [String: Int] = [:] // Tracks total scores across all questions
    
    var totalQuestions: Int {
        multiplayerManager.gameSettings?.questionCount ?? 12
    }
    
    var maxTimeToAnswer: TimeInterval {
        TimeInterval(multiplayerManager.gameSettings?.timeToAnswer ?? 30)
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
        
        multiplayerManager.onHostDisconnected = { [weak self] in
            guard let self = self else { return }
            // Don't show alert if game is already finished
            if !self.showFinalResults && !self.isFinalLeaderboard {
                self.hostDisconnected = true
            }
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
        
        // Clear previous question's correct answers NOW (at start of new question)
        correctPlayers = []
        
        // Generate random question based on settings
        let question = generateQuestion(from: settings)
        currentQuestion = question
        
        // Broadcast to all players
        print("📤 Host broadcasting question \(currentQuestionNumber): \(question.questionText)")
        multiplayerManager.broadcastQuestion(question)
        
        // Reset for new question
        resetForNewQuestion()
        
        // Start timer
        startQuestionTimer()
    }
    
    private func generateQuestion(from settings: MultiplayerGameSettings) -> TriviaQuestion {
        // Randomly select from settings
        let position = settings.positions.randomElement() ?? "Quarterback"
        let team = settings.teams.randomElement() ?? "KC"
        let year = Int.random(in: settings.yearFrom...settings.yearTo)
        
        // Query real players from database
        let singlePlayerPositions = ["Quarterback", "Tight End", "Kicker"]
        
        if singlePlayerPositions.contains(position) {
            // Get top 1 player for single-player positions
            let snapType = position == "Kicker" ? "special_teams" : "offense"
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: position,
                year: year,
                team: team,
                snapType: snapType
            ) {
                return TriviaQuestion(
                    playerFirstName: topPlayer.firstName,
                    playerLastName: topPlayer.lastName,
                    position: position,
                    team: team,
                    year: year
                )
            }
        } else {
            // Get multiple players for multi-player positions
            let limit = getPlayerLimit(for: position)
            let snapType = ["Linebacker", "Defensive Back", "Defensive Linemen"].contains(position) ? "defense" : "offense"
            
            let players = DatabaseManager.shared.getTopPlayersAtPosition(
                position: position,
                year: year,
                team: team,
                limit: limit,
                snapType: snapType
            )
            
            if let randomPlayer = players.randomElement() {
                return TriviaQuestion(
                    playerFirstName: randomPlayer.firstName,
                    playerLastName: randomPlayer.lastName,
                    position: position,
                    team: team,
                    year: year
                )
            }
        }
        
        // Fallback if no player found - try another combination
        return generateQuestion(from: settings)
    }
    
    private func getPlayerLimit(for position: String) -> Int {
        switch position {
        case "Offensive Linemen":
            return 5
        case "Defensive Back":
            return 4
        case "Wide Receiver", "Linebacker", "Defensive Linemen":
            return 3
        default: // Running Back
            return 2
        }
    }
    
    // MARK: - Question Management (Player)
    
    private func receiveQuestion(_ question: TriviaQuestion) {
        print("📩 Player received question \(currentQuestionNumber + 1): \(question.questionText)")
        
        // Clear previous question's correct answers NOW (at start of new question)
        correctPlayers = []
        
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
    
    func submitAnswer(_ answer: String) {
        guard let question = currentQuestion, !hasAnswered, !isValidating else { return }
        
        isValidating = true
        stopQuestionTimer()
        
        let responseTime = Date().timeIntervalSince(answerStartTime ?? Date())
        
        // Use Firebase validation for answer checking
        validateAnswerWithFirebase(answer: answer, question: question, responseTime: responseTime)
    }
    
    private func validateAnswerWithFirebase(answer: String, question: TriviaQuestion, responseTime: TimeInterval) {
        // Get all valid players for this position/team/year
        let limit = getPlayerLimit(for: question.position)
        let singlePlayerPositions = ["Quarterback", "Tight End", "Kicker"]
        let snapType: String
        
        if question.position == "Kicker" {
            snapType = "special_teams"
        } else if ["Linebacker", "Defensive Back", "Defensive Linemen"].contains(question.position) {
            snapType = "defense"
        } else {
            snapType = "offense"
        }
        
        let players: [Player]
        if singlePlayerPositions.contains(question.position) {
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: question.position,
                year: question.year,
                team: question.team,
                snapType: snapType
            ) {
                players = [topPlayer]
            } else {
                players = []
            }
        } else {
            players = DatabaseManager.shared.getTopPlayersAtPosition(
                position: question.position,
                year: question.year,
                team: question.team,
                limit: limit,
                snapType: snapType
            )
        }
        
        // Store correct players for display
        self.correctPlayers = players
        
        // Set a flag to track if validation completed
        var validationCompleted = false
        
        // Timeout after 10 seconds - submit with fallback validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, !validationCompleted else { return }
            validationCompleted = true
            
            print("⚠️ Firebase validation timeout - using fallback")
            self.handleFallbackValidation(answer: answer, question: question, players: players, responseTime: responseTime)
        }
        
        // Validate with Firebase
        FirebaseService.shared.validateAnswerAndProvideInfo(
            userAnswer: answer,
            correctPlayers: players,
            position: question.position,
            year: question.year,
            team: question.team
        ) { [weak self] result in
            guard let self = self else { return }
            guard !validationCompleted else { return }
            validationCompleted = true
            
            switch result {
            case .success(let validationResponse):
                let isCorrect = validationResponse.isCorrect
                self.lastAnswerCorrect = isCorrect
                self.hasAnswered = true
                self.isValidating = false
                
                if isCorrect {
                    // Award points based on speed
                    // Scale: 10 points for instant, decreases proportionally with time
                    let maxPoints = 10
                    let timeLimit = self.maxTimeToAnswer
                    let points = max(1, maxPoints - Int((responseTime / timeLimit) * Double(maxPoints - 1)))
                    self.currentQuestionPoints = points
                    self.currentPlayerScore += points
                } else {
                    self.currentQuestionPoints = 0
                }
                
                // Submit to multiplayer manager
                self.multiplayerManager.submitAnswer(answer, isCorrect: isCorrect, responseTime: responseTime)
                
            case .failure(let error):
                print("❌ Firebase validation error: \(error.localizedDescription)")
                self.handleFallbackValidation(answer: answer, question: question, players: players, responseTime: responseTime)
            }
        }
    }
    
    private func handleFallbackValidation(answer: String, question: TriviaQuestion, players: [Player], responseTime: TimeInterval) {
        // Fallback validation - check against all valid players (not just the one shown)
        let playerAnswer = answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        var isCorrect = false
        
        // Check if answer matches any of the valid players for this position/team/year
        for player in players {
            let fullName = "\(player.firstName) \(player.lastName)".lowercased()
            let lastName = player.lastName.lowercased()
            let firstName = player.firstName.lowercased()
            
            // Check for various matching patterns
            if playerAnswer == fullName ||  // Exact full name match
               playerAnswer == lastName ||  // Last name only
               playerAnswer == firstName || // First name only
               fullName.contains(playerAnswer) ||  // Answer is part of full name
               playerAnswer.contains(lastName) {   // Answer contains last name
                isCorrect = true
                break
            }
        }
        
        self.lastAnswerCorrect = isCorrect
        self.hasAnswered = true
        self.isValidating = false
        
        if isCorrect {
            // Award points based on speed (same formula as Firebase validation)
            let maxPoints = 10
            let timeLimit = self.maxTimeToAnswer
            let points = max(1, maxPoints - Int((responseTime / timeLimit) * Double(maxPoints - 1)))
            self.currentQuestionPoints = points
            self.currentPlayerScore += points
        } else {
            self.currentQuestionPoints = 0
        }
        
        self.multiplayerManager.submitAnswer(answer, isCorrect: isCorrect, responseTime: responseTime)
    }
    
    private func receiveAnswer(from playerID: String, answer: String, isCorrect: Bool, responseTime: TimeInterval) {
        guard multiplayerManager.isHost else { return }
        
        // Calculate points using same formula
        let maxPoints = 10
        let timeLimit = maxTimeToAnswer
        let points = isCorrect ? max(1, maxPoints - Int((responseTime / timeLimit) * Double(maxPoints - 1))) : 0
        
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
        timeRemaining = 20.0
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
            currentQuestionPoints = 0
            
            // Populate correctPlayers so they can see what the answer was
            if let question = currentQuestion, correctPlayers.isEmpty {
                populateCorrectPlayersForDisplay(question: question)
            }
            
            // Submit as incorrect with max time
            multiplayerManager.submitAnswer("", isCorrect: false, responseTime: maxTimeToAnswer)
        }
    }
    
    private func populateCorrectPlayersForDisplay(question: TriviaQuestion) {
        // Get all valid players for display when time expires or answer is wrong
        let limit = getPlayerLimit(for: question.position)
        let singlePlayerPositions = ["Quarterback", "Tight End", "Kicker"]
        let snapType: String
        
        if question.position == "Kicker" {
            snapType = "special_teams"
        } else if ["Linebacker", "Defensive Back", "Defensive Linemen"].contains(question.position) {
            snapType = "defense"
        } else {
            snapType = "offense"
        }
        
        if singlePlayerPositions.contains(question.position) {
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: question.position,
                year: question.year,
                team: question.team,
                snapType: snapType
            ) {
                correctPlayers = [topPlayer]
            } else {
                correctPlayers = []
            }
        } else {
            correctPlayers = DatabaseManager.shared.getTopPlayersAtPosition(
                position: question.position,
                year: question.year,
                team: question.team,
                limit: limit,
                snapType: snapType
            )
        }
        
        print("📋 Populated correct players for display: \(correctPlayers.map { "\($0.firstName) \($0.lastName)" }.joined(separator: ", "))")
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
        
        // Show answer for 5 seconds, then leaderboard
        startAnswerDisplayTimer()
    }
    
    private func startAnswerDisplayTimer() {
        answerDisplayTimeRemaining = 8.0  // Increased from 5 to 8 seconds for better readability
        
        answerDisplayTimer?.invalidate()
        answerDisplayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                self.answerDisplayTimeRemaining -= 0.1
                
                if self.answerDisplayTimeRemaining <= 0 {
                    self.hideAnswerAndShowLeaderboard()
                }
            }
        }
    }
    
    private func hideAnswerAndShowLeaderboard() {
        answerDisplayTimer?.invalidate()
        answerDisplayTimer = nil
        
        // Show leaderboard
        showLeaderboard = true
        isFinalLeaderboard = currentQuestionNumber >= totalQuestions
        
        if !isFinalLeaderboard {
            startLeaderboardTimer()
        }
    }
    
    private func calculateLeaderboard() -> [LeaderboardEntry] {
        // Update cumulative scores from current question's answers
        for (playerName, answer) in playerAnswers {
            cumulativeScores[playerName, default: 0] += answer.points
            print("📊 Updated cumulative score for \(playerName): \(cumulativeScores[playerName] ?? 0) (+\(answer.points))")
        }
        
        // Add host's cumulative score if not already tracked
        let hostName = multiplayerManager.playerName
        if cumulativeScores[hostName] == nil {
            cumulativeScores[hostName] = currentPlayerScore
        }
        
        print("📊 Current cumulative scores: \(cumulativeScores)")
        
        // Create leaderboard entries from cumulative scores
        let unsortedEntries = cumulativeScores.map { name, score -> LeaderboardEntry in
            // Get current response time from playerAnswers if available
            let responseTime = playerAnswers[name]?.responseTime ?? 0
            return LeaderboardEntry(
                id: name,
                playerName: name,
                score: score,
                averageResponseTime: responseTime
            )
        }
        
        // Sort by score (descending), then by response time (ascending)
        let entries = unsortedEntries.sorted { first, second in
            if first.score != second.score {
                return first.score > second.score
            }
            return first.averageResponseTime < second.averageResponseTime
        }
        
        return entries
    }
    
    private func updateLeaderboard(_ entries: [LeaderboardEntry]) {
        leaderboard = entries
        isFinalLeaderboard = currentQuestionNumber >= totalQuestions
        
        // Update local player's score from leaderboard (ensures sync with host's calculation)
        // Do this IMMEDIATELY for all players (including host) to ensure header shows correct score
        if let myEntry = entries.first(where: { $0.playerName == multiplayerManager.playerName }) {
            print("📊 Updating score from leaderboard: \(currentPlayerScore) → \(myEntry.score)")
            currentPlayerScore = myEntry.score
        }
        
        // Ensure correctPlayers is populated so answer screen shows properly
        // This handles cases where validation was fast or time expired without populating
        if correctPlayers.isEmpty, let question = currentQuestion {
            print("⚠️ correctPlayers empty when leaderboard arrived - populating now")
            populateCorrectPlayersForDisplay(question: question)
        }
        
        // Players: show answer for 5 seconds first, then leaderboard
        if !multiplayerManager.isHost {
            startAnswerDisplayTimer()
        } else {
            // Host already showing answer, just show leaderboard
            showLeaderboard = true
            if !isFinalLeaderboard {
                startLeaderboardTimer()
            }
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
        
        // Auto-load next question for host
        if multiplayerManager.isHost {
            multiplayerManager.broadcastNextQuestion()
            loadNextQuestion()
        }
    }
    
    // MARK: - Game End
    
    private func endGame() {
        stopQuestionTimer()
        leaderboardTimer?.invalidate()
        answerDisplayTimer?.invalidate()
        
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
        isValidating = false
        lastAnswerCorrect = false
        currentQuestionPoints = 0
        hasUsedHint = false
        generalHint = ""
        moreObviousHint = ""
        // DON'T clear correctPlayers here - it needs to display during answer screen
        timeRemaining = maxTimeToAnswer
        playerAnswers.removeAll()
    }
    
    func requestHint() {
        guard let question = currentQuestion else { return }
        hasUsedHint = true
        
        // Generate general hint
        generalHint = "Position: \(question.position)\nTeam: \(question.team)\nYear: \(question.year)"
        
        // Generate more obvious hint if enabled
        if multiplayerManager.gameSettings?.moreObviousHintsEnabled == true {
            if let firstPlayer = correctPlayers.first {
                let firstNameHint = String(firstPlayer.firstName.prefix(2)) + "..." 
                let lastNameHint = String(firstPlayer.lastName.prefix(1)) + "..."
                moreObviousHint = "First Name starts with: \(firstNameHint)\nLast Name starts with: \(lastNameHint)"
            }
        }
        
        showHintSheet = true
    }
    
    deinit {
        questionTimer?.invalidate()
        leaderboardTimer?.invalidate()
        answerDisplayTimer?.invalidate()
    }
}

// MARK: - Supporting Types

struct PlayerAnswer {
    let answer: String
    let isCorrect: Bool
    let responseTime: TimeInterval
    let points: Int
}
