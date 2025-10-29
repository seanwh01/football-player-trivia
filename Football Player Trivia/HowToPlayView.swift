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
            // Black background
            Color.black
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
                            "Settings determine the parameters of play",
                            "Spin the wheels to select Position, Year and Team",
                            "Each spin locks in a selection",
                            "No Spin needed if there is only a single selection",
                            "After all three spins, enter the player's name",
                            "Get hints if you need help (General or More Obvious - based on settings)",
                            "Track your success rate within a session",
                            "Play as many questions as you want"
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
                            "The game auto selects the upcoming game from the current season schedule based on your favorite team setting",
                            "The game will ask all positional questions for both teams (every question unique, no repeats)",
                            "Scoreboard shows number of questions answered correctly for each team",
                            "Each question worth one point",
                            "Halftime show appears at the halfway point",
                            "Game summary shows positional battle winner and overall winner"
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
                            "Host sets up game parameters",
                            "  • Number of questions",
                            "  • Time to answer",
                            "  • Enable/disable hints",
                            "  • Parameters for positions, year(s), and team(s)",
                            "  • The parameters selected must support the number of questions to enable uniqueness",
                            "Players join by clicking Head to Head Trivia Game on their application and selecting \"Join Nearby Game\"",
                            "System randomly selects questions based on parameters host set",
                            "All questions will be unique",
                            "All players race to answer correctly",
                            "Points are awarded based on time needed to answer correctly",
                            "Live leaderboard between questions"
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
                            "Players need to keep app open the entire game",
                            "Don't switch to other apps or lock your device",
                            "Stay within 30 feet of each other for best results",
                            "If Host closes game, game ends for all",
                            "Supports up to 8 players, though results may improve with 6 or less"
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
