# Multiplayer Head-to-Head Trivia Game

## Overview
Interactive multiplayer trivia game using Apple's Multipeer Connectivity framework for local network gaming with up to 8 players.

## Features
- ✅ **Host-based multiplayer** (1 host + up to 7 players)
- ✅ **Automatic device discovery** via Multipeer Connectivity
- ✅ **10-second answer timer** with visual countdown
- ✅ **Live leaderboard** (5-second display between questions)
- ✅ **Customizable game parameters** (positions, teams, years, question count)
- ✅ **Real-time scoring** based on speed and accuracy
- ✅ **No hints allowed** in multiplayer mode
- ✅ **Banner ads** displayed (no interstitials)

## Game Flow

### Host Flow:
1. Tap "Head to Head Trivia Game" → "Host Game"
2. Enter your name
3. Select game parameters:
   - Number of questions (8, 12, or 24)
   - Year range (2016-2025)
   - Positions (must select at least 1)
   - Teams (must select at least 1)
   - **At least one category must have 2+ selections**
4. Tap "Host Game" → Wait in lobby for players
5. When ready (minimum 2 players), tap "Start Game"
6. Spin for each player (only host spins)
7. After all players answer (or timer expires), view leaderboard
8. Continue until all questions complete
9. View final winner announcement

### Player Flow:
1. Tap "Head to Head Trivia Game" → "Join Nearby Game"
2. Enter your name
3. Tap "Find Nearby Games"
4. Select host from list of available games
5. Wait in lobby for host to start
6. Answer questions within 10 seconds
7. View leaderboard after each question
8. See final scores and winner

## Scoring System
- **10 points max** per correct answer
- **Points decrease** based on response time:
  - 0-1 seconds: 10 points
  - 1-2 seconds: 9 points
  - ...continuing...
  - 9-10 seconds: 1 point
- **0 points** for incorrect answers or timeouts

## Technical Implementation

### Core Components:

**MultiplayerManager.swift**
- Manages Multipeer Connectivity session
- Handles peer discovery, invitations, and messaging
- Broadcasts questions, answers, and leaderboards
- Supports up to 8 simultaneous players

**MultiplayerHostSetupView.swift**
- Host configuration screen
- Game parameter selection
- Validation for multi-value requirements

**MultiplayerJoinView.swift**
- Player name entry
- Nearby game discovery
- Connection to host

**MultiplayerLobbyView.swift**
- Pre-game waiting room
- Shows connected players
- Host can start game when ready (2+ players)

**MultiplayerGameView.swift**
- Main game interface
- Question display with timer
- Answer submission
- Leaderboard transitions
- Final results

**MultiplayerGameViewModel.swift**
- Game state management
- Timer logic (10s questions, 5s leaderboards)
- Answer validation
- Score calculation
- Message handling

**TriviaQuestion.swift**
- Question data model
- Player information encapsulation

### Privacy Permissions (Info.plist):
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to find and connect with nearby players for multiplayer trivia games.</string>

<key>NSBonjourServices</key>
<array>
    <string>_nfl-trivia._tcp</string>
    <string>_nfl-trivia._udp</string>
</array>
```

## Testing

### Requirements:
- **2+ iOS devices** on the same Wi-Fi network OR in Bluetooth range
- **iOS 14.0+** (Multipeer Connectivity requirement)

### Test Scenarios:

1. **Basic Flow (2 players)**
   - Host creates game with 8 questions
   - 1 player joins
   - Complete full game
   - Verify winner display

2. **Multiple Players (3-8)**
   - Host creates game
   - Multiple players join
   - Verify all see same questions
   - Verify leaderboard updates correctly

3. **Timer Behavior**
   - Player answers before timer expires
   - Player lets timer expire (0 points)
   - All players answer quickly (< 10s total wait)

4. **Edge Cases**
   - Player leaves mid-game
   - Host leaves mid-game
   - Connection loss during question
   - Rejoin after disconnect

5. **Game Parameters**
   - Single position, multiple teams
   - Multiple positions, single team
   - Multiple years (verify random selection)
   - Different question counts (8, 12, 24)

## Known Limitations

1. **Local network only** - Multipeer Connectivity requires same Wi-Fi or Bluetooth range
2. **8 player maximum** - Multipeer Connectivity limit
3. **No rejoin** - Players who disconnect cannot rejoin mid-game
4. **No persistence** - Game state not saved if app backgrounds
5. **Demo questions** - Currently uses sample player data (integrate with database for production)

## Production Integration TODO

- [ ] Replace `generateQuestion()` in `MultiplayerGameViewModel.swift` with actual database queries
- [ ] Integrate Firebase answer validation (currently using simple string comparison)
- [ ] Add player stats tracking across games
- [ ] Implement persistent leaderboards
- [ ] Add game history/replay
- [ ] Handle network interruptions gracefully
- [ ] Add sound effects for correct/incorrect answers
- [ ] Implement chat/emoji reactions between questions
- [ ] Add game modes (speed round, elimination, etc.)

## Files Added

- `MultiplayerManager.swift`
- `MultiplayerHostSetupView.swift`
- `MultiplayerJoinView.swift`
- `MultiplayerLobbyView.swift`
- `MultiplayerGameView.swift`
- `MultiplayerGameViewModel.swift`
- `TriviaQuestion.swift`

## Files Modified

- `ContentView.swift` - Added multiplayer button and navigation
- `Info.plist` - Added Multipeer Connectivity permissions

## Branch

This feature is developed on the `NewHeadtoHeadPlay` feature branch.
