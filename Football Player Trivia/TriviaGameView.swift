//
//  TriviaGameView.swift
//  Football Trivia
//
//  Main trivia game view with spinning wheels
//

import SwiftUI
import UIKit

struct TriviaGameView: View {
    @ObservedObject var settings: GameSettings
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedPosition: String = "< Spin the Wheel >"
    @State private var selectedYear: String = "< Spin the Wheel >"
    @State private var selectedTeam: String = "< Spin the Wheel >"
    @State private var playerName: String = ""
    
    @State private var positionLocked: Bool = false
    @State private var yearLocked: Bool = false
    @State private var teamLocked: Bool = false
    
    @State private var showResult: Bool = false
    @State private var resultMessage: String = ""
    @State private var isCorrect: Bool = false
    
    @State private var hintMessage: String = ""
    @State private var isLoadingHint: Bool = false
    
    @State private var activeAlert: AlertType? = nil
    @State private var isValidatingAnswer: Bool = false
    @State private var isLoadingIDontKnow: Bool = false
    @State private var bannerAdRefreshTrigger: Int = 0
    @State private var isReady: Bool = false
    @State private var pendingHint: (year: Int, hintLevel: String)? = nil
    @State private var lastHintContext: (year: Int, position: String, team: String)? = nil
    @State private var spinCount: Int = 0 // Track spins for interstitial ads
    @State private var shouldShowAdAfterAnswer: Bool = false // Flag to show ad after answer
    
    // Challenge mode tracking (for Upcoming Game Challenge)
    @State private var teamScores: [String: Int] = [:]
    @State private var currentGameTeams: [String] = []
    @State private var currentQuestionNumber: Int = 0
    @State private var totalQuestions: Int = 0
    @State private var showHalftimeShow: Bool = false
    @State private var showGameOver: Bool = false
    @State private var usedCombinations: Set<String> = []
    @State private var questionHistory: [(team: String, position: String)] = []
    
    @FocusState private var isTextFieldFocused: Bool
    
    @StateObject private var adManager = AdMobManager.shared
    
    enum AlertType: Identifiable {
        case result
        case hint
        
        var id: Int {
            hashValue
        }
    }
    
    private var isPositionActive: Bool {
        !positionLocked && isReady
    }
    
    private var isYearActive: Bool {
        positionLocked && !yearLocked
    }
    
    private var isTeamActive: Bool {
        positionLocked && yearLocked && !teamLocked
    }
    
    private var isPlayerInputActive: Bool {
        positionLocked && yearLocked && teamLocked
    }
    
    private var isInChallengeMode: Bool {
        !currentGameTeams.isEmpty
    }
    
    private var availableTeamsForYear: [String] {
        if yearLocked, let year = Int(selectedYear) {
            let teams = settings.getTeamsForYear(year)
            return filterTeamsForCombination(teams, year: selectedYear)
        } else {
            let teams = settings.getAvailableTeams()
            return filterTeamsForCombination(teams, year: selectedYear)
        }
    }
    
    private var playerPrompt: String {
        switch selectedPosition {
        case "Quarterback":
            return "Name the starting Quarterback:"
        case "Running Back":
            return "Name one of the top two Running Backs:"
        case "Wide Receiver":
            return "Name one of the top three Wide Receivers:"
        case "Tight End":
            return "Name the starting Tight End:"
        case "Offensive Linemen":
            return "Name one of the top five Offensive Linemen:"
        case "Linebacker":
            return "Name one of the top three Linebackers:"
        case "Defensive Back":
            return "Name one of the top four Defensive Backs:"
        case "Defensive Linemen":
            return "Name one of the top three Defensive Linemen:"
        case "Placekicker":
            return "Name the Placekicker:"
        default:
            return "Name that Player:"
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            GeometryReader { geometry in
                Image("FootballFieldBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.4))
            }
            .ignoresSafeArea()
            
            VStack(spacing: 15) {
                // Title
                VStack(spacing: 5) {
                    Text("Spin for a Player!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "hand.draw.fill")
                            .foregroundColor(.yellow)
                        Text("Swipe DOWN ↓ on each box to spin!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.yellow)
                        Image(systemName: "hand.draw.fill")
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                }
                .padding(.top, 10)
                .padding(.bottom, 5)
                
                // Position Wheel
                SpinnerField(
                    label: "Position",
                    selectedValue: $selectedPosition,
                    values: getAvailablePositions(),
                    isActive: isPositionActive,
                    isLocked: positionLocked,
                    onSpinComplete: {
                        positionLocked = true
                        autoSelectSingleValues()
                    },
                    hapticsEnabled: settings.spinHapticsEnabled
                )
                
                // Year Wheel
                SpinnerField(
                    label: "Year",
                    selectedValue: $selectedYear,
                    values: getAvailableYears(),
                    isActive: isYearActive,
                    isLocked: yearLocked,
                    onSpinComplete: {
                        yearLocked = true
                        autoSelectSingleValues()
                    },
                    hapticsEnabled: settings.spinHapticsEnabled
                )
                
                // Team Wheel
                SpinnerField(
                    label: "Team",
                    selectedValue: $selectedTeam,
                    values: availableTeamsForYear,
                    isActive: isTeamActive,
                    isLocked: teamLocked,
                    onSpinComplete: {
                        teamLocked = true
                        bannerAdRefreshTrigger += 1
                        autoSelectSingleValues()
                        
                        // Track spins for interstitial ad (show after answer submission)
                        if !isInChallengeMode {
                            spinCount += 1
                            if spinCount % 8 == 0 {
                                shouldShowAdAfterAnswer = true
                            }
                        }
                    },
                    hapticsEnabled: settings.spinHapticsEnabled
                )
                .id(selectedYear)
                
                // Player Name Input
                VStack(alignment: .leading, spacing: 10) {
                    Text(playerPrompt)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .opacity(isPlayerInputActive ? 1.0 : 0.5)
                    
                    TextField("Enter player name", text: $playerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .padding(.horizontal, 20)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .disabled(!isPlayerInputActive)
                        .opacity(isPlayerInputActive ? 1.0 : 0.5)
                        .focused($isTextFieldFocused)
                        .onChange(of: isPlayerInputActive) { isActive in
                            if isActive {
                                // Auto-focus text field when it becomes active
                                // Small delay ensures wheel animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isTextFieldFocused = true
                                }
                            }
                        }
                    
                    HStack(spacing: 10) {
                        Spacer()
                        
                        Button(action: checkAnswer) {
                            HStack(spacing: 5) {
                                if isValidatingAnswer {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                                Text(isValidatingAnswer ? "Checking..." : "Submit")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isPlayerInputActive ? Color.orange : Color.gray)
                            .cornerRadius(8)
                        }
                        .disabled(!isPlayerInputActive || playerName.trimmingCharacters(in: .whitespaces).isEmpty || isValidatingAnswer)
                        
                        Button(action: getHint) {
                            HStack(spacing: 5) {
                                if isLoadingHint {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                                Text(isLoadingHint ? "Thinking..." : "Hint")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(isPlayerInputActive ? Color.orange : Color.gray)
                            .cornerRadius(8)
                        }
                        .disabled(!isPlayerInputActive || isLoadingHint)
                        
                        // "I don't know" button - get answer with AI facts
                        Button(action: skipToAnswer) {
                            HStack(spacing: 5) {
                                if isLoadingIDontKnow {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                                Image(systemName: "sparkles")
                                    .foregroundColor(.white)
                                Text(isLoadingIDontKnow ? "Loading..." : "I Don't Know")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                            .background(isPlayerInputActive ? Color(red: 1.0, green: 0.4, blue: 0.7) : Color.gray)
                            .cornerRadius(8)
                        }
                        .disabled(!isPlayerInputActive || isLoadingIDontKnow)
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 10)
                
                // Scoreboard (for Challenge Mode)
                if isInChallengeMode {
                    CompactScoreboardView(
                        teams: currentGameTeams,
                        scores: teamScores,
                        questionNumber: currentQuestionNumber,
                        totalQuestions: totalQuestions
                    )
                    .transition(.scale.combined(with: .opacity))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                
                Spacer(minLength: 10)
                
                // Banner Ad
                if bannerAdRefreshTrigger > 0 {
                    BannerAdContainer(
                        adUnitID: adManager.getBannerAdUnitID(),
                        refreshTrigger: $bannerAdRefreshTrigger
                    )
                    .padding(.bottom, 5)
                    .transition(.opacity)
                }
                
                // Session Stats & Attribution
                VStack(spacing: 3) {
                    Text("You've answered \(settings.sessionCorrect) correctly out of \(settings.sessionTotal) spins.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 2) {
                        Text("Data courtesy of the nflverse project")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                        Link("(https://github.com/nflverse)", destination: URL(string: "https://github.com/nflverse")!)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                        Text("used under the MIT License.")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 3)
                }
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("Pigskin Genius")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert(item: $activeAlert) { alertType in
            createAlert(for: alertType)
        }
        .onAppear {
            isReady = true
            autoSelectSingleValues()
            setupNotifications()
            initializeScoreboard()
            
            // Load first interstitial ad
            adManager.loadInterstitialAd()
        }
        .onDisappear {
            removeNotifications()
            
            // Reset challenge mode state when leaving the game
            // This prevents scoreboard from appearing in Single Player mode
            currentGameTeams = []
            teamScores = [:]
            currentQuestionNumber = 0
            totalQuestions = 0
            usedCombinations = []
            questionHistory = []
            showHalftimeShow = false
            showGameOver = false
            
            // CRITICAL: Reset selected teams to all teams
            // Otherwise Single Player mode will detect 2 teams and show scoreboard
            settings.selectedTeams = Set(settings.allTeams)
        }
        .sheet(isPresented: $showHalftimeShow) {
            HalftimeShowView(
                teams: currentGameTeams,
                scores: teamScores,
                onContinue: {
                    showHalftimeShow = false
                }
            )
        }
        .overlay {
            if showGameOver {
                GameOverView(
                    teams: currentGameTeams,
                    scores: teamScores,
                    questionHistory: questionHistory,
                    onClose: {
                        closeGame()
                    },
                    onPlayAgain: {
                        playAgain()
                    }
                )
                .transition(.opacity)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func autoSelectSingleValues() {
        let positions = getAvailablePositions()
        if positions.count == 1, let single = positions.first {
            selectedPosition = single
            positionLocked = true
        }
        
        if positionLocked {
            let years = getAvailableYears()
            if years.count == 1, let single = years.first {
                selectedYear = single
                yearLocked = true
            }
        }
        
        if yearLocked {
            let teams = availableTeamsForYear
            if teams.count == 1, let single = teams.first {
                selectedTeam = single
                teamLocked = true
                bannerAdRefreshTrigger += 1
            }
        }
    }
    
    private func createAlert(for type: AlertType) -> Alert {
        switch type {
        case .result:
            return Alert(
                title: Text("Result"),
                message: Text(resultMessage),
                dismissButton: .default(Text("Next Question")) {
                    // Check if we should show ad after this answer (every 8 spins in single player)
                    if shouldShowAdAfterAnswer && !isInChallengeMode {
                        showInterstitialAd()
                        shouldShowAdAfterAnswer = false
                    }
                    
                    // Check if game over after final question in challenge mode
                    if isInChallengeMode && currentQuestionNumber >= totalQuestions {
                        // Show interstitial ad before game over screen
                        showInterstitialAd()
                        
                        // Delay showing game over to allow ad to be dismissed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showGameOver = true
                        }
                        return
                    }
                    
                    // Check if halftime (halfway point)
                    if isInChallengeMode && currentQuestionNumber == totalQuestions / 2 {
                        showHalftimeShow = true
                    }
                    resetForNextQuestion()
                }
            )
        case .hint:
            if settings.hintLevel == "General" {
                return Alert(
                    title: Text("💡 Hint"),
                    message: Text(hintMessage),
                    primaryButton: .default(Text("More Obvious")) {
                        activeAlert = nil
                        getMoreObviousHint()
                    },
                    secondaryButton: .cancel(Text("OK")) {
                        activeAlert = nil
                        isLoadingHint = false
                    }
                )
            } else {
                return Alert(
                    title: Text("💡 Hint"),
                    message: Text(hintMessage),
                    dismissButton: .default(Text("OK")) {
                        activeAlert = nil
                        isLoadingHint = false
                    }
                )
            }
        }
    }
    
    private func resetForNextQuestion() {
        activeAlert = nil
        isTextFieldFocused = false
        selectedPosition = "< Spin the Wheel >"
        selectedYear = "< Spin the Wheel >"
        selectedTeam = "< Spin the Wheel >"
        playerName = ""
        positionLocked = false
        yearLocked = false
        teamLocked = false
        showResult = false
        
        // Auto-select single values (works with filtered combinations)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            autoSelectSingleValues()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("InterstitialAdDismissed"),
            object: nil,
            queue: .main
        ) { [self] _ in
            if let pending = pendingHint {
                pendingHint = nil
                generateHint(year: pending.year, forceHintLevel: pending.hintLevel)
            }
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("InterstitialAdDismissed"),
            object: nil
        )
    }
    
    // MARK: - Helper Functions
    
    private func getAvailablePositions() -> [String] {
        // If not in challenge mode, return all positions
        if !isInChallengeMode {
            return settings.getAvailablePositions()
        }
        
        // In challenge mode, filter out positions with no remaining combinations
        return settings.getAvailablePositions().filter { position in
            hasAvailableCombination(position: position)
        }
    }
    
    private func getAvailableYears() -> [String] {
        // If not in challenge mode, return all years
        if !isInChallengeMode || !positionLocked {
            return settings.getAvailableYears()
        }
        
        // In challenge mode, filter years that still have valid combinations
        return settings.getAvailableYears().filter { year in
            hasAvailableTeamsForYear(position: selectedPosition, year: year)
        }
    }
    
    private func filterTeamsForCombination(_ teams: [String], year: String) -> [String] {
        // If not in challenge mode, return all teams
        if !isInChallengeMode || !positionLocked || !yearLocked {
            return teams
        }
        
        // In challenge mode, filter out used combinations
        return teams.filter { team in
            let combo = "\(selectedPosition)|\(year)|\(team)"
            return !usedCombinations.contains(combo)
        }
    }
    
    private func hasAvailableCombination(position: String) -> Bool {
        let allYears = settings.getAvailableYears()
        for year in allYears {
            let teams = settings.getTeamsForYear(Int(year) ?? 0)
            for team in teams where currentGameTeams.contains(team) {
                let combo = "\(position)|\(year)|\(team)"
                if !usedCombinations.contains(combo) {
                    return true
                }
            }
        }
        return false
    }
    
    private func hasAvailableTeamsForYear(position: String, year: String) -> Bool {
        let teams = settings.getTeamsForYear(Int(year) ?? 0)
        for team in teams where currentGameTeams.contains(team) {
            let combo = "\(position)|\(year)|\(team)"
            if !usedCombinations.contains(combo) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Scoreboard Management
    
    private func initializeScoreboard() {
        // Initialize scoreboard on game start
        updateScoreboardDisplay()
    }
    
    private func updateScoreboardDisplay() {
        // Only show scoreboard if exactly 2 teams are selected (challenge mode)
        let availableTeams = settings.getAvailableTeams()
        
        if availableTeams.count == 2 {
            let sortedTeams = availableTeams.sorted()
            
            // Check if teams changed (new challenge started)
            if currentGameTeams != sortedTeams {
                // Reset scores, question counter, and used combinations for new teams
                teamScores = [:]
                currentQuestionNumber = 0
                usedCombinations = []
                questionHistory = []
                currentGameTeams = sortedTeams
                
                // Calculate total questions: positions × years × 2 teams
                let positions = settings.getAvailablePositions()
                let years = settings.getAvailableYears()
                totalQuestions = positions.count * years.count * 2
                
                // Initialize scores for both teams
                for team in currentGameTeams {
                    teamScores[team] = 0
                }
            }
        } else {
            // Clear scoreboard if not in 2-team challenge mode
            currentGameTeams = []
            usedCombinations = []
            questionHistory = []
            totalQuestions = 0
        }
    }
    
    private func updateTeamScore(for team: String, position: String) {
        teamScores[team, default: 0] += 1
        questionHistory.append((team: team, position: position))
    }
    
    private func closeGame() {
        // End challenge mode - reset to all teams
        settings.selectedTeams = Set(settings.allTeams)
        
        // Reset all game state
        teamScores = [:]
        currentGameTeams = []
        currentQuestionNumber = 0
        totalQuestions = 0
        usedCombinations = []
        questionHistory = []
        showGameOver = false
        
        // Reset wheel state
        resetForNextQuestion()
        
        // Navigate back to welcome screen
        presentationMode.wrappedValue.dismiss()
    }
    
    private func playAgain() {
        // Keep the same 2 teams, just reset scores and start over
        teamScores = [:]
        currentQuestionNumber = 0
        usedCombinations = []
        questionHistory = []
        showGameOver = false
        
        // Initialize scores for both teams
        for team in currentGameTeams {
            teamScores[team] = 0
        }
        
        // Reset wheel state
        resetForNextQuestion()
    }
    
    // MARK: - Game Logic
    
    private func checkAnswer() {
        guard !playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let yearInt = Int(selectedYear) else { return }
        
        isValidatingAnswer = true
        isTextFieldFocused = false
        
        // Get correct players from database based on position type
        let players: [Player]
        let singlePlayerPositions = ["Quarterback", "Tight End", "Placekicker"]
        
        if singlePlayerPositions.contains(selectedPosition) {
            // Get top 1 player for single-player positions
            let snapType = selectedPosition == "Placekicker" ? "special_teams" : "offense"
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: selectedPosition,
                year: yearInt,
                team: selectedTeam,
                snapType: snapType
            ) {
                players = [topPlayer]
            } else {
                players = []
            }
        } else {
            // Get top N players for multi-player positions
            var limit: Int
            switch selectedPosition {
            case "Offensive Linemen":
                limit = 5
            case "Defensive Back":
                limit = 4
            case "Wide Receiver", "Linebacker", "Defensive Linemen":
                limit = 3
            default: // Running Back
                limit = 2
            }
            
            let snapType = ["Linebacker", "Defensive Back", "Defensive Linemen"].contains(selectedPosition) ? "defense" : "offense"
            players = DatabaseManager.shared.getTopPlayersAtPosition(
                position: selectedPosition,
                year: yearInt,
                team: selectedTeam,
                limit: limit,
                snapType: snapType
            )
        }
        
        guard !players.isEmpty else {
            self.isValidatingAnswer = false
            self.resultMessage = "❌ No player data found for this selection."
            self.isCorrect = false
            self.activeAlert = .result
            return
        }
        
        // Call Firebase to validate answer
        FirebaseService.shared.validateAnswerAndProvideInfo(
            userAnswer: self.playerName,
            correctPlayers: players,
            position: self.selectedPosition,
            year: yearInt,
            team: self.selectedTeam
        ) { result in
            self.isValidatingAnswer = false
            
            switch result {
            case .success(let response):
                self.isCorrect = response.isCorrect
                self.resultMessage = response.message
                
                if response.isCorrect {
                    self.settings.sessionCorrect += 1
                    
                    // Update team score if in challenge mode
                    if self.isInChallengeMode {
                        self.updateTeamScore(for: self.selectedTeam, position: self.selectedPosition)
                    }
                }
                self.settings.sessionTotal += 1
                
                // Increment question counter and mark combination as used in challenge mode
                if self.isInChallengeMode {
                    self.currentQuestionNumber += 1
                    
                    // Mark this combination as used to prevent duplicates
                    let combo = "\(self.selectedPosition)|\(self.selectedYear)|\(self.selectedTeam)"
                    self.usedCombinations.insert(combo)
                }
                
                // Update scoreboard display
                self.updateScoreboardDisplay()
                
                self.activeAlert = .result
                
                // Refresh banner ad after submission
                self.bannerAdRefreshTrigger += 1
                
            case .failure(let error):
                self.resultMessage = "Error: \(error.localizedDescription)"
                self.isCorrect = false
                self.activeAlert = .result
                
                // Refresh banner ad after submission
                self.bannerAdRefreshTrigger += 1
            }
        }
    }
    
    private func showInterstitialAd() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Try to show interstitial ad
        _ = adManager.showInterstitialAd(from: rootViewController)
    }
    
    private func getHint() {
        guard let yearInt = Int(selectedYear) else { return }
        // Save context for potential "More Obvious" request
        lastHintContext = (year: yearInt, position: selectedPosition, team: selectedTeam)
        generateHint(year: yearInt)
    }
    
    private func skipToAnswer() {
        guard let yearInt = Int(selectedYear) else { return }
        
        isLoadingIDontKnow = true
        isTextFieldFocused = false
        
        // Get correct players from database based on position type
        let players: [Player]
        let singlePlayerPositions = ["Quarterback", "Tight End", "Placekicker"]
        
        if singlePlayerPositions.contains(selectedPosition) {
            // Get top 1 player for single-player positions
            let snapType = selectedPosition == "Placekicker" ? "special_teams" : "offense"
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: selectedPosition,
                year: yearInt,
                team: selectedTeam,
                snapType: snapType
            ) {
                players = [topPlayer]
            } else {
                players = []
            }
        } else {
            // Get top N players for multi-player positions
            var limit: Int
            switch selectedPosition {
            case "Offensive Linemen":
                limit = 5
            case "Defensive Back":
                limit = 4
            case "Wide Receiver", "Linebacker", "Defensive Linemen":
                limit = 3
            default: // Running Back
                limit = 2
            }
            
            let snapType = ["Linebacker", "Defensive Back", "Defensive Linemen"].contains(selectedPosition) ? "defense" : "offense"
            players = DatabaseManager.shared.getTopPlayersAtPosition(
                position: selectedPosition,
                year: yearInt,
                team: selectedTeam,
                limit: limit,
                snapType: snapType
            )
        }
        
        guard !players.isEmpty else {
            self.isLoadingIDontKnow = false
            self.resultMessage = "❌ No player data found for this selection."
            self.isCorrect = false
            self.activeAlert = .result
            return
        }
        
        // Call Firebase to get player info (pass empty string to skip validation)
        FirebaseService.shared.validateAnswerAndProvideInfo(
            userAnswer: "",  // Empty answer - just want info
            correctPlayers: players,
            position: self.selectedPosition,
            year: yearInt,
            team: self.selectedTeam
        ) { result in
            self.isLoadingIDontKnow = false
            
            switch result {
            case .success(let response):
                // Always mark as incorrect since user didn't answer
                self.isCorrect = false
                self.resultMessage = response.message
                
                // Increment session total but not correct count
                self.settings.sessionTotal += 1
                
                self.activeAlert = .result
                
            case .failure(let error):
                self.resultMessage = "❌ Error getting player info: \(error.localizedDescription)"
                self.isCorrect = false
                self.activeAlert = .result
            }
        }
    }
    
    private func getMoreObviousHint() {
        guard let context = lastHintContext else { return }
        // Keep loading state active and generate new hint
        isLoadingHint = true
        generateHint(year: context.year, forceHintLevel: "More Obvious")
    }
    
    private func generateHint(year: Int, forceHintLevel: String? = nil) {
        isLoadingHint = true
        
        let hintLevel = forceHintLevel ?? settings.hintLevel
        
        // Get correct players from database based on position type
        let players: [Player]
        let singlePlayerPositions = ["Quarterback", "Tight End", "Placekicker"]
        
        if singlePlayerPositions.contains(selectedPosition) {
            // Get top 1 player for single-player positions
            let snapType = selectedPosition == "Placekicker" ? "special_teams" : "offense"
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: selectedPosition,
                year: year,
                team: selectedTeam,
                snapType: snapType
            ) {
                players = [topPlayer]
            } else {
                players = []
            }
        } else {
            // Get top N players for multi-player positions
            var limit: Int
            switch selectedPosition {
            case "Offensive Linemen":
                limit = 5
            case "Defensive Back":
                limit = 4
            case "Wide Receiver", "Linebacker", "Defensive Linemen":
                limit = 3
            default: // Running Back
                limit = 2
            }
            
            let snapType = ["Linebacker", "Defensive Back", "Defensive Linemen"].contains(selectedPosition) ? "defense" : "offense"
            players = DatabaseManager.shared.getTopPlayersAtPosition(
                position: selectedPosition,
                year: year,
                team: selectedTeam,
                limit: limit,
                snapType: snapType
            )
        }
        
        guard !players.isEmpty else {
            self.isLoadingHint = false
            self.hintMessage = "No player data found for this selection."
            self.activeAlert = .hint
            return
        }
        
        // Increment hint count
        settings.sessionHintCount += 1
        
        // Check if we should show an interstitial ad (every 4th hint)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Try to show interstitial ad if threshold reached
            let adShown = adManager.showInterstitialIfNeeded(
                hintCount: settings.sessionHintCount,
                from: rootViewController
            )
            
            if adShown {
                // Store year and hint level for after ad dismisses
                pendingHint = (year: year, hintLevel: hintLevel)
                isLoadingHint = false
                return
            }
        }
        
        // Call Firebase to generate hint
        FirebaseService.shared.generateHint(
            for: players,
            position: self.selectedPosition,
            year: year,
            team: self.selectedTeam,
            hintLevel: hintLevel
        ) { result in
            self.isLoadingHint = false
            
            switch result {
            case .success(let hint):
                self.hintMessage = hint
                self.activeAlert = .hint
                
            case .failure(let error):
                self.hintMessage = "Unable to generate hint: \(error.localizedDescription)"
                self.activeAlert = .hint
            }
        }
    }
}

// MARK: - Spinner Field Component

struct SpinnerField: View {
    let label: String
    @Binding var selectedValue: String
    let values: [String]
    let isActive: Bool
    let isLocked: Bool
    let onSpinComplete: () -> Void
    let hapticsEnabled: Bool
    
    @State private var isSpinning = false
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var spinTimer: Timer?
    @State private var spinStartTime: Date?
    @State private var totalSpinCount = 0
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let minimumSpinDuration: TimeInterval = 1.5  // Spin for at least 1.5 seconds
    private let minimumCycles = 2  // Go through all values at least twice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.leading, 5)
            
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(isActive ? Color.white.opacity(0.9) : Color.white.opacity(0.5))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isActive ? Color.white : Color.clear, lineWidth: 3)
                    )
                
                // Show swipe hint if not spun yet
                if isActive && selectedValue == "< Spin the Wheel >" && !isSpinning {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("Swipe Down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(isSpinning ? values[currentIndex] : selectedValue)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(selectedValue == "< Spin the Wheel >" ? .gray : .white)
                        .padding()
                }
            }
            .overlay(
                Group {
                    if isLocked && !isActive {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(8)
                    }
                }
                , alignment: .bottomTrailing
            )
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if isActive && !isLocked && gesture.translation.height > 50 {
                            if !isSpinning {
                                startSpinning()
                            }
                        }
                    }
                    .onEnded { _ in
                        if isSpinning {
                            stopSpinning()
                        }
                    }
            )
        }
        .padding(.horizontal, 20)
    }
    
    private func startSpinning() {
        guard !values.isEmpty else { return }
        
        isSpinning = true
        currentIndex = Int.random(in: 0..<values.count)  // Start at random position
        totalSpinCount = 0
        spinStartTime = Date()
        
        if hapticsEnabled {
            impactFeedback.impactOccurred()
        }
        
        // Spin through values - 0.05 seconds per value change
        spinTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
            currentIndex = (currentIndex + 1) % values.count
            totalSpinCount += 1
            
            if hapticsEnabled {
                selectionFeedback.selectionChanged()
            }
        }
    }
    
    private func stopSpinning() {
        guard let startTime = spinStartTime else { return }
        
        // Calculate how much more time we need
        let elapsed = Date().timeIntervalSince(startTime)
        let timeRemaining = max(0, minimumSpinDuration - elapsed)
        
        // Calculate how many more spins we need to complete minimum cycles
        let minimumSpins = values.count * minimumCycles
        let spinsRemaining = max(0, minimumSpins - totalSpinCount)
        let timeForRemainingSpins = Double(spinsRemaining) * 0.05
        
        // Add random extra spins (0-10 additional spins) for unpredictability
        let randomExtraSpins = Int.random(in: 0...10)
        let randomExtraTime = Double(randomExtraSpins) * 0.05
        
        // Wait for whichever is longest
        let waitTime = max(timeRemaining, timeForRemainingSpins) + randomExtraTime
        
        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
            spinTimer?.invalidate()
            spinTimer = nil
            
            selectedValue = values[currentIndex]
            isSpinning = false
            
            if hapticsEnabled {
                impactFeedback.impactOccurred()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSpinComplete()
            }
        }
    }
}

#Preview {
    TriviaGameView(settings: GameSettings())
}
