//
//  HowToPlayView.swift
//  Football Player Trivia
//
//  Comprehensive guide for all game modes and tips
//

import SwiftUI

struct HowToPlayView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.0, green: 0.3, blue: 0.1),
                    Color(red: 0.1, green: 0.5, blue: 0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image("PigskinGeniusLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                        
                        Text("How to Play")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Master all game modes!")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    
                    // Single Player Trivia
                    GameModeSection(
                        icon: "person.fill",
                        iconColor: .blue,
                        title: "Single Player Trivia Game",
                        description: "Test your NFL knowledge solo",
                        steps: [
                            "Spin the wheel to select Position, Year, and Team",
                            "Each spin locks in a selection",
                            "After all three spins, enter the player's name",
                            "Get hints if you need help (General or More Obvious)",
                            "Track your progress with session stats",
                            "Play as many questions as you want!"
                        ]
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                    
                    // Upcoming Game Challenge
                    GameModeSection(
                        icon: "calendar",
                        iconColor: .orange,
                        title: "Upcoming Game Challenge",
                        description: "Compete between two teams from an upcoming NFL matchup",
                        steps: [
                            "Select from real upcoming NFL games",
                            "Play a complete game with all positions for both teams",
                            "Every question is unique - no repeats!",
                            "Scoreboard shows Question X of Y (e.g., Question 5 of 18)",
                            "Correct answers score points for that team",
                            "Halftime show appears at the halfway point",
                            "Game Over summary shows position battles and winner",
                            "Challenge yourself to beat both teams!"
                        ]
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                    
                    // Head to Head Multiplayer
                    GameModeSection(
                        icon: "person.2.fill",
                        iconColor: .blue,
                        title: "Head to Head Trivia Game",
                        description: "Compete against friends in real-time multiplayer",
                        steps: [
                            "Host creates a game and sets options:",
                            "  • Number of questions (5-20)",
                            "  • Time per question (10-60 seconds)",
                            "  • Enable/disable hints",
                            "Players join using the lobby code",
                            "Host spins for each question's criteria",
                            "All players race to answer correctly",
                            "Faster correct answers = more points!",
                            "Live leaderboard between questions",
                            "Final results show winner and stats"
                        ]
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                    
                    // Multiplayer Tips
                    TipsSection(
                        title: "Multiplayer Tips & Connectivity",
                        icon: "wifi",
                        tips: [
                            "All devices must be on the same WiFi network",
                            "Bluetooth must be enabled on all devices",
                            "Stay within 30 feet of each other for best connection",
                            "Host should not leave - game will end for all players",
                            "If connection issues occur, restart the game",
                            "3-8 players recommended for best experience",
                            "Text field auto-focuses - start typing immediately!",
                            "Practice with Single Player to learn player names"
                        ]
                    )
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.vertical, 8)
                    
                    // General Tips
                    TipsSection(
                        title: "Pro Tips",
                        icon: "star.fill",
                        tips: [
                            "First and last names are usually enough (e.g., 'Patrick Mahomes')",
                            "Nicknames sometimes work (e.g., 'Pat Mahomes')",
                            "Spelling matters - use hints if unsure",
                            "Session stats track your progress",
                            "Different years = different rosters",
                            "Position battles show team depth",
                            "Text field auto-focuses after each spin/question",
                            "Speed matters in multiplayer mode!"
                        ]
                    )
                    
                    // Close button
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Got It!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.top, 16)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.title2)
                }
            }
        }
    }
}

// MARK: - Game Mode Section

struct GameModeSection: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Steps
            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        if steps[index].hasPrefix("  • ") {
                            // Sub-item
                            Text("  •")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 14))
                        } else {
                            // Main item
                            Text("•")
                                .foregroundColor(.orange)
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        Text(steps[index].trimmingCharacters(in: CharacterSet(charactersIn: " •")))
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Tips Section

struct TipsSection: View {
    let title: String
    let icon: String
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.yellow)
                    .frame(width: 32)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Text("💡")
                            .font(.system(size: 14))
                        
                        Text(tips[index])
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        HowToPlayView()
    }
}
