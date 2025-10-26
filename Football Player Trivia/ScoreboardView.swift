//
//  ScoreboardView.swift
//  Football Player Trivia
//
//  TV broadcast-style scoreboard for tracking team scores
//

import SwiftUI

struct ScoreboardView: View {
    let teams: [String]
    let scores: [String: Int]
    
    var body: some View {
        VStack(spacing: 0) {
            // Scoreboard container with TV broadcast styling
            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("CHALLENGE SCOREBOARD")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.9))
                
                // Team scores stacked vertically
                ForEach(teams, id: \.self) { team in
                    teamRow(team: team, score: scores[team] ?? 0)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.95), Color.gray.opacity(0.9)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.8), lineWidth: 3)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 20)
    }
    
    private func teamRow(team: String, score: Int) -> some View {
        HStack(spacing: 12) {
            // Team abbreviation with team color background
            Text(team)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(teamColor(for: team))
                .cornerRadius(6)
            
            // Team name (full)
            Text(teamFullName(for: team))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Score with animated background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 60, height: 44)
                
                Text("\(score)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.3))
    }
    
    private func teamColor(for team: String) -> Color {
        // NFL team colors (simplified)
        let teamColors: [String: Color] = [
            "KC": Color.red,
            "SF": Color(red: 0.7, green: 0.1, blue: 0.1),
            "DAL": Color(red: 0.0, green: 0.2, blue: 0.5),
            "NE": Color(red: 0.0, green: 0.1, blue: 0.3),
            "GB": Color(red: 0.1, green: 0.3, blue: 0.1),
            "PIT": Color.yellow,
            "BAL": Color(red: 0.3, green: 0.1, blue: 0.5),
            "PHI": Color(red: 0.0, green: 0.3, blue: 0.3),
            "SEA": Color(red: 0.0, green: 0.2, blue: 0.4),
            "DEN": Color.orange,
            "MIA": Color(red: 0.0, green: 0.5, blue: 0.5),
            "LA": Color(red: 0.0, green: 0.2, blue: 0.5),
            "CHI": Color(red: 0.0, green: 0.2, blue: 0.4),
            "MIN": Color(red: 0.3, green: 0.1, blue: 0.5),
            "NYG": Color.blue,
            "WAS": Color(red: 0.5, green: 0.2, blue: 0.2),
            "CIN": Color(red: 1.0, green: 0.5, blue: 0.0),
            "BUF": Color.blue,
            "CLE": Color(red: 0.3, green: 0.15, blue: 0.0),
            "IND": Color.blue,
            "JAX": Color(red: 0.0, green: 0.4, blue: 0.4),
            "TEN": Color(red: 0.0, green: 0.2, blue: 0.4),
            "LAC": Color(red: 0.0, green: 0.3, blue: 0.5),
            "LV": Color.gray,
            "ATL": Color.red,
            "CAR": Color.blue,
            "NO": Color(red: 0.8, green: 0.7, blue: 0.3),
            "TB": Color.red,
            "ARI": Color.red,
            "NYJ": Color(red: 0.0, green: 0.3, blue: 0.2),
            "HOU": Color(red: 0.0, green: 0.2, blue: 0.4),
            "DET": Color.blue
        ]
        
        return teamColors[team] ?? Color.blue
    }
    
    private func teamFullName(for team: String) -> String {
        let teamNames: [String: String] = [
            "ARI": "Cardinals", "ATL": "Falcons", "BAL": "Ravens", "BUF": "Bills",
            "CAR": "Panthers", "CHI": "Bears", "CIN": "Bengals", "CLE": "Browns",
            "DAL": "Cowboys", "DEN": "Broncos", "DET": "Lions", "GB": "Packers",
            "HOU": "Texans", "IND": "Colts", "JAX": "Jaguars", "KC": "Chiefs",
            "LAC": "Chargers", "LA": "Rams", "LV": "Raiders", "MIA": "Dolphins",
            "MIN": "Vikings", "NE": "Patriots", "NO": "Saints", "NYG": "Giants",
            "NYJ": "Jets", "PHI": "Eagles", "PIT": "Steelers", "SF": "49ers",
            "SEA": "Seahawks", "TB": "Buccaneers", "TEN": "Titans", "WAS": "Commanders"
        ]
        
        return teamNames[team] ?? team
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ScoreboardView(teams: ["KC", "WAS"], scores: ["KC": 3, "WAS": 2])
    }
}
