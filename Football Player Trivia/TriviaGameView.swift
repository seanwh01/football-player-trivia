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
    @State private var bannerAdRefreshTrigger: Int = 0
    @State private var isReady: Bool = false
    @State private var pendingHintYear: Int? = nil
    @State private var lastHintContext: (year: Int, position: String, team: String)? = nil
    
    @FocusState private var isTextFieldFocused: Bool
    
    // Disabled to prevent delays - re-enable when ads are optimized
    // @StateObject private var adManager = AdMobManager.shared
    
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
    
    private var availableTeamsForYear: [String] {
        if yearLocked, let year = Int(selectedYear) {
            return settings.getTeamsForYear(year)
        } else {
            return settings.getAvailableTeams()
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
            return "Name one of the top two Tight Ends:"
        case "Linebacker":
            return "Name one of the top three Linebackers:"
        case "Cornerback":
            return "Name one of the top three Cornerbacks:"
        case "Safety":
            return "Name one of the top two Safeties:"
        case "Defensive Line":
            return "Name one of the top three Defensive Linemen:"
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
                    values: settings.getAvailablePositions(),
                    isActive: isPositionActive,
                    isLocked: positionLocked,
                    onSpinComplete: {
                        positionLocked = true
                    },
                    hapticsEnabled: settings.spinHapticsEnabled
                )
                
                // Year Wheel
                SpinnerField(
                    label: "Year",
                    selectedValue: $selectedYear,
                    values: settings.getAvailableYears(),
                    isActive: isYearActive,
                    isLocked: yearLocked,
                    onSpinComplete: {
                        yearLocked = true
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
                    
                    HStack(spacing: 15) {
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
                            .padding(.horizontal, 25)
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
                            .padding(.horizontal, 25)
                            .padding(.vertical, 10)
                            .background(isPlayerInputActive ? Color.orange : Color.gray)
                            .cornerRadius(8)
                        }
                        .disabled(!isPlayerInputActive || isLoadingHint)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 10)
                
                Spacer(minLength: 10)
                
                // Banner Ad - Disabled to prevent 12 second WebView delays
                // TODO: Re-enable after optimizing ad loading
                // if bannerAdRefreshTrigger > 0 {
                //     BannerAdContainer(
                //         adUnitID: adManager.getBannerAdUnitID(),
                //         refreshTrigger: $bannerAdRefreshTrigger
                //     )
                //     .padding(.bottom, 5)
                //     .transition(.opacity)
                // }
                
                // Session Stats & Attribution
                VStack(spacing: 3) {
                    Text("You've answered \(settings.sessionCorrect) correctly out of \(settings.sessionTotal) spins.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("ℹ️ Player data © nflverse — used with permission. github.com/nflverse")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.6))
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
        }
        .onDisappear {
            removeNotifications()
        }
    }
    
    // MARK: - Helper Methods
    
    private func autoSelectSingleValues() {
        let positions = settings.getAvailablePositions()
        if positions.count == 1, let single = positions.first {
            selectedPosition = single
            positionLocked = true
        }
        
        let years = settings.getAvailableYears()
        if years.count == 1, let single = years.first {
            selectedYear = single
            yearLocked = true
        }
        
        if yearLocked, let year = Int(selectedYear) {
            let teams = settings.getTeamsForYear(year)
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
        autoSelectSingleValues()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("InterstitialAdDismissed"),
            object: nil,
            queue: .main
        ) { [self] _ in
            if let year = pendingHintYear {
                pendingHintYear = nil
                generateHint(year: year)
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
    
    // MARK: - Game Logic
    
    private func checkAnswer() {
        guard !playerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard let yearInt = Int(selectedYear) else { return }
        
        isValidatingAnswer = true
        isTextFieldFocused = false
        
        // Get correct players from database based on position type
        let players: [Player]
        let singlePlayerPositions = ["Quarterback", "Tight End"]
        
        if singlePlayerPositions.contains(selectedPosition) {
            // Get top 1 player for single-player positions
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: selectedPosition,
                year: yearInt,
                team: selectedTeam
            ) {
                players = [topPlayer]
            } else {
                players = []
            }
        } else {
            // Get top 2-3 players for multi-player positions
            let limit = ["Wide Receiver", "Linebacker", "Cornerback", "Defensive Line"].contains(selectedPosition) ? 3 : 2
            let snapType = ["Linebacker", "Cornerback", "Safety", "Defensive Line"].contains(selectedPosition) ? "defense" : "offense"
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
                }
                self.settings.sessionTotal += 1
                
                self.activeAlert = .result
                
            case .failure(let error):
                self.resultMessage = "Error: \(error.localizedDescription)"
                self.isCorrect = false
                self.activeAlert = .result
            }
        }
    }
    
    private func getHint() {
        guard let yearInt = Int(selectedYear) else { return }
        // Save context for potential "More Obvious" request
        lastHintContext = (year: yearInt, position: selectedPosition, team: selectedTeam)
        generateHint(year: yearInt)
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
        let singlePlayerPositions = ["Quarterback", "Tight End"]
        
        if singlePlayerPositions.contains(selectedPosition) {
            // Get top 1 player for single-player positions
            if let topPlayer = DatabaseManager.shared.getTopPlayerAtPosition(
                position: selectedPosition,
                year: year,
                team: selectedTeam
            ) {
                players = [topPlayer]
            } else {
                players = []
            }
        } else {
            // Get top 2-3 players for multi-player positions
            let limit = ["Wide Receiver", "Linebacker", "Cornerback", "Defensive Line"].contains(selectedPosition) ? 3 : 2
            let snapType = ["Linebacker", "Cornerback", "Safety", "Defensive Line"].contains(selectedPosition) ? "defense" : "offense"
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
