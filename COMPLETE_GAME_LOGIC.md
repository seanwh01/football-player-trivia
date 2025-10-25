# Complete Football Trivia Game Logic

This guide shows how to complete the game logic in `TriviaGameView.swift` by adding Firebase integration (adapted from Baseball Player Trivia).

---

## Quick Summary

Replace 3 stub methods in `TriviaGameView.swift`:
1. `checkAnswer()` - Validate player name with Firebase
2. `getHint()` - Generate AI hints
3. `generateHint()` - Helper for hint generation

Plus add helper methods for database queries and ad display.

---

## Complete Code to Add

Add these complete implementations to `TriviaGameView.swift`:

### 1. Helper: Get Correct Players

```swift
// Add this helper method
private func getCorrectPlayers(position: String, year: Int, team: String) -> [Player] {
    switch position {
    case "Quarterback", "Tight End":
        // Single player positions
        if let player = DatabaseManager.shared.getTopPlayerAtPosition(
            position: position,
            year: year,
            team: team,
            snapType: "offense"
        ) {
            return [player]
        }
        return []
        
    case "Running Back":
        return DatabaseManager.shared.getTopPlayersAtPosition(
            position: position,
            year: year,
            team: team,
            limit: 2,
            snapType: "offense"
        )
        
    case "Wide Receiver":
        return DatabaseManager.shared.getTopPlayersAtPosition(
            position: position,
            year: year,
            team: team,
            limit: 3,
            snapType: "offense"
        )
        
    case "Linebacker", "Cornerback", "Defensive Line":
        return DatabaseManager.shared.getTopPlayersAtPosition(
            position: position,
            year: year,
            team: team,
            limit: 3,
            snapType: "defense"
        )
        
    case "Safety":
        return DatabaseManager.shared.getTopPlayersAtPosition(
            position: position,
            year: year,
            team: team,
            limit: 2,
            snapType: "defense"
        )
        
    default:
        return []
    }
}
```

### 2. Helper: Get Root View Controller

```swift
private func getRootViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = windowScene.windows.first?.rootViewController else {
        return nil
    }
    
    var topController = rootViewController
    while let presented = topController.presentedViewController {
        topController = presented
    }
    
    return topController
}
```

### 3. Replace checkAnswer() stub

```swift
private func checkAnswer() {
    guard let year = Int(selectedYear) else { return }
    
    let userAnswer = playerName.trimmingCharacters(in: .whitespaces)
    isValidatingAnswer = true
    
    let correctPlayers = getCorrectPlayers(position: selectedPosition, year: year, team: selectedTeam)
    
    guard !correctPlayers.isEmpty else {
        isValidatingAnswer = false
        isCorrect = false
        resultMessage = "No data found for this combination."
        playerName = ""
        isTextFieldFocused = false
        activeAlert = .result
        return
    }
    
    FirebaseService.shared.validateAnswerAndProvideInfo(
        userAnswer: userAnswer,
        correctPlayers: correctPlayers,
        position: selectedPosition,
        year: year,
        team: selectedTeam
    ) { result in
        self.isValidatingAnswer = false
        switch result {
        case .success(let response):
            self.isCorrect = response.isCorrect
            self.resultMessage = response.message
            self.settings.sessionTotal += 1
            if response.isCorrect {
                self.settings.sessionCorrect += 1
            }
            self.playerName = ""
            self.isTextFieldFocused = false
            self.activeAlert = .result
            
        case .failure(let error):
            self.isCorrect = false
            self.resultMessage = "Error: \(error.localizedDescription)"
            self.playerName = ""
            self.isTextFieldFocused = false
            self.activeAlert = .result
        }
    }
}
```

### 4. Replace getHint() stub

```swift
private func getHint() {
    guard let year = Int(selectedYear) else { return }
    
    lastHintContext = (year: year, position: selectedPosition, team: selectedTeam)
    settings.sessionHintCount += 1
    
    if settings.sessionHintCount == 1 && !adManager.isInterstitialReady {
        adManager.loadInterstitialAd()
    }
    
    var adShown = false
    if let viewController = getRootViewController() {
        adShown = adManager.showInterstitialIfNeeded(
            hintCount: settings.sessionHintCount,
            from: viewController
        )
    }
    
    if adShown {
        pendingHintYear = year
        isLoadingHint = true
    } else {
        isLoadingHint = true
        generateHint(year: year)
    }
}
```

### 5. Replace generateHint() stub

```swift
private func generateHint(year: Int, forceHintLevel: String? = nil) {
    let hintLevelToUse = forceHintLevel ?? settings.hintLevel
    let correctPlayers = getCorrectPlayers(position: selectedPosition, year: year, team: selectedTeam)
    
    guard !correctPlayers.isEmpty else {
        isLoadingHint = false
        hintMessage = "No player data found."
        activeAlert = .hint
        return
    }
    
    FirebaseService.shared.generateHint(
        for: correctPlayers,
        position: selectedPosition,
        year: year,
        team: selectedTeam,
        hintLevel: hintLevelToUse
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
```

### 6. Replace getMoreObviousHint() stub

```swift
private func getMoreObviousHint() {
    guard let context = lastHintContext else { return }
    
    settings.sessionHintCount += 1
    
    if settings.sessionHintCount == 1 && !adManager.isInterstitialReady {
        adManager.loadInterstitialAd()
    }
    
    var adShown = false
    if let viewController = getRootViewController() {
        adShown = adManager.showInterstitialIfNeeded(
            hintCount: settings.sessionHintCount,
            from: viewController
        )
    }
    
    if adShown {
        pendingHintYear = context.year
        isLoadingHint = true
    } else {
        isLoadingHint = true
        generateHint(year: context.year, forceHintLevel: "More Obvious")
    }
}
```

---

## Testing

Test with: **QB → 2023 → KC**
- Expected: Patrick Mahomes
- Enter "mahomes" → Should validate as correct!

---

**That's it! Add these 6 methods and your game logic is complete!** 🏈
