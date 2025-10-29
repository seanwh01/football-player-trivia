//
//  GameOverView.swift
//  Football Player Trivia
//
//  Game over screen showing final score and winner
//

import SwiftUI

struct GameOverView: View {
    let teams: [String]
    let scores: [String: Int]
    let questionHistory: [(team: String, position: String)]
    let onClose: () -> Void
    let onPlayAgain: () -> Void
    
    private var winner: (team: String, score: Int)? {
        guard let team1 = teams.first, let team2 = teams.last,
              let score1 = scores[team1], let score2 = scores[team2] else {
            return nil
        }
        
        if score1 > score2 {
            return (team1, score1)
        } else if score2 > score1 {
            return (team2, score2)
        } else {
            return nil // Tie
        }
    }
    
    private var gameSummary: String {
        guard teams.count == 2 else { return "" }
        
        let team1 = teams[0]
        let team2 = teams[1]
        let score1 = scores[team1] ?? 0
        let score2 = scores[team2] ?? 0
        
        var summary = ""
        
        // Position battles
        var team1Positions: Set<String> = []
        var team2Positions: Set<String> = []
        var tiedPositions: Set<String> = []
        
        let allPositions = Set(questionHistory.map { $0.position })
        
        for position in allPositions {
            let team1Count = questionHistory.filter { $0.team == team1 && $0.position == position }.count
            let team2Count = questionHistory.filter { $0.team == team2 && $0.position == position }.count
            
            if team1Count > team2Count {
                team1Positions.insert(position)
            } else if team2Count > team1Count {
                team2Positions.insert(position)
            } else {
                tiedPositions.insert(position)
            }
        }
        
        if !team1Positions.isEmpty || !team2Positions.isEmpty {
            if !team1Positions.isEmpty {
                let positionList = team1Positions.sorted().joined(separator: ", ")
                summary += "The position battle for \(positionList) was won by \(team1)"
                if !team2Positions.isEmpty {
                    let positionList2 = team2Positions.sorted().joined(separator: ", ")
                    summary += ", while \(team2) won \(positionList2). "
                } else {
                    summary += ". "
                }
            } else if !team2Positions.isEmpty {
                let positionList = team2Positions.sorted().joined(separator: ", ")
                summary += "The position battle for \(positionList) was won by \(team2). "
            }
        }
        
        if !tiedPositions.isEmpty {
            let positionList = tiedPositions.sorted().joined(separator: ", ")
            summary += "There was no clear winner in these positions: \(positionList). "
        }
        
        // Final score commentary
        if score1 > score2 {
            summary += "The final score was telling though as \(team1) won the game!"
        } else if score2 > score1 {
            summary += "The final score was telling though as \(team2) won the game!"
        } else {
            summary = "This one was just too close to call and there is no overtime in Pigskin Genius! There's always next game."
        }
        
        return summary
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(maxHeight: .infinity)
            
            // Game Over Popup
            VStack(spacing: 15) {
                // Game Over Title
                Text("GAME OVER!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Winner or Tie (more compact)
                if let winner = winner {
                    HStack(spacing: 8) {
                        Text(winner.team)
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.yellow)
                        Text("WINS!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                } else {
                    Text("IT'S A TIE!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .padding(.vertical, 8)
                }
                
                // Final Scores (more compact)
                VStack(spacing: 8) {
                    Text("Final Score")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    ForEach(teams, id: \.self) { team in
                        HStack(spacing: 12) {
                            Text(team)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60)
                            
                            Text("\(scores[team] ?? 0)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.yellow)
                                .frame(width: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
                
                // Game Summary Narrative
                VStack(alignment: .leading, spacing: 5) {
                    Text("Game Summary")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                    
                    ScrollView {
                        Text(gameSummary)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(height: 120)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .padding(.horizontal, 15)
                
                // Buttons (more compact)
                HStack(spacing: 12) {
                    // Close Game Button
                    Button(action: onClose) {
                        VStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                            Text("Close Game")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .cornerRadius(10)
                        .shadow(color: Color.red.opacity(0.5), radius: 6, x: 0, y: 3)
                    }
                    
                    // Play Again Button
                    Button(action: onPlayAgain) {
                        VStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 20))
                            Text("Play Again")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(color: Color.green.opacity(0.5), radius: 6, x: 0, y: 3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 360)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.95), Color.gray.opacity(0.9)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.orange.opacity(0.8), lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 30)
            .padding(.bottom, 150) // Leave space for scoreboard
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5).ignoresSafeArea())
    }
}

#Preview {
    ZStack {
        Color.green.opacity(0.3).ignoresSafeArea()
        GameOverView(
            teams: ["KC", "WAS"],
            scores: ["KC": 5, "WAS": 3],
            questionHistory: [
                (team: "KC", position: "Quarterback"),
                (team: "WAS", position: "Wide Receiver"),
                (team: "KC", position: "Wide Receiver"),
                (team: "WAS", position: "Linebacker"),
                (team: "KC", position: "Quarterback"),
                (team: "KC", position: "Tight End"),
                (team: "KC", position: "Running Back"),
                (team: "WAS", position: "Defensive Back")
            ],
            onClose: {},
            onPlayAgain: {}
        )
    }
}
