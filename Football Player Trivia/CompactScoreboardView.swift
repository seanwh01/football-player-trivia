//
//  CompactScoreboardView.swift
//  Football Player Trivia
//
//  Compact TV broadcast-style scoreboard for challenge mode
//

import SwiftUI

struct CompactScoreboardView: View {
    let teams: [String]
    let scores: [String: Int]
    let questionNumber: Int
    
    private var quarterInfo: (quarter: String, progress: String) {
        // TODO: Change back to 20 questions (5 per quarter) for production
        // Currently: 8 questions (2 per quarter) for testing
        // questionNumber = number of questions ANSWERED, shows UPCOMING question
        let questionsPerQuarter = 2  // Change to 5 for production
        let totalQuestions = questionsPerQuarter * 4
        
        if questionNumber == 0 {
            return ("Pre-Game", "\(totalQuestions) Question Challenge")
        } else if questionNumber < questionsPerQuarter {
            // In Q1, show upcoming question
            return ("First Quarter", "Q\(questionNumber + 1) of \(questionsPerQuarter)")
        } else if questionNumber == questionsPerQuarter {
            // Just finished Q1, starting Q2
            return ("Start of Second Quarter", "Q1 of \(questionsPerQuarter)")
        } else if questionNumber < questionsPerQuarter * 2 {
            // In Q2, show upcoming question
            let nextQ = (questionNumber % questionsPerQuarter) + 1
            return ("Second Quarter", "Q\(nextQ) of \(questionsPerQuarter)")
        } else if questionNumber == questionsPerQuarter * 2 {
            // Just finished Q2, starting Q3
            return ("Start of Third Quarter", "Q1 of \(questionsPerQuarter)")
        } else if questionNumber < questionsPerQuarter * 3 {
            // In Q3, show upcoming question
            let nextQ = (questionNumber % questionsPerQuarter) + 1
            return ("Third Quarter", "Q\(nextQ) of \(questionsPerQuarter)")
        } else if questionNumber == questionsPerQuarter * 3 {
            // Just finished Q3, starting Q4
            return ("Start of Fourth Quarter", "Q1 of \(questionsPerQuarter)")
        } else if questionNumber < questionsPerQuarter * 4 {
            // In Q4, show upcoming question
            let nextQ = (questionNumber % questionsPerQuarter) + 1
            return ("Fourth Quarter", "Q\(nextQ) of \(questionsPerQuarter)")
        } else {
            return ("Final Score", "")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Quarter header
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Text(quarterInfo.quarter)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    if !quarterInfo.progress.isEmpty {
                        Text(quarterInfo.progress)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.yellow)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.9))
            
            HStack(spacing: 0) {
            // Left team
            if teams.count > 0 {
                teamCompactRow(team: teams[0], score: scores[teams[0]] ?? 0, isLeft: true)
            }
            
            // VS divider
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text("VS")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(width: 36)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            
            // Right team
            if teams.count > 1 {
                teamCompactRow(team: teams[1], score: scores[teams[1]] ?? 0, isLeft: false)
            }
            }
            .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.95), Color.gray.opacity(0.85)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow.opacity(0.7), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
    }
    
    private func teamCompactRow(team: String, score: Int, isLeft: Bool) -> some View {
        HStack(spacing: 6) {
            if !isLeft {
                // Score on left for right team
                scoreBox(score: score)
            }
            
            VStack(spacing: 2) {
                // Team abbreviation
                Text(team)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                // Team name
                Text(teamShortName(for: team))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(teamColor(for: team).opacity(0.3))
            
            if isLeft {
                // Score on right for left team
                scoreBox(score: score)
            }
        }
        .background(Color.black.opacity(0.4))
    }
    
    private func scoreBox(score: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Text("\(score)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 4)
    }
    
    private func teamColor(for team: String) -> Color {
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
            "BUF": Color.blue,
            "CIN": Color.orange,
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
            "HOU": Color(red: 0.0, green: 0.2, blue: 0.3),
            "DET": Color.blue
        ]
        
        return teamColors[team] ?? Color.blue
    }
    
    private func teamShortName(for team: String) -> String {
        let teamNames: [String: String] = [
            "ARI": "Cards", "ATL": "Falcons", "BAL": "Ravens", "BUF": "Bills",
            "CAR": "Panthers", "CHI": "Bears", "CIN": "Bengals", "CLE": "Browns",
            "DAL": "Cowboys", "DEN": "Broncos", "DET": "Lions", "GB": "Packers",
            "HOU": "Texans", "IND": "Colts", "JAX": "Jaguars", "KC": "Chiefs",
            "LAC": "Chargers", "LA": "Rams", "LV": "Raiders", "MIA": "Dolphins",
            "MIN": "Vikings", "NE": "Patriots", "NO": "Saints", "NYG": "Giants",
            "NYJ": "Jets", "PHI": "Eagles", "PIT": "Steelers", "SF": "49ers",
            "SEA": "Seahawks", "TB": "Bucs", "TEN": "Titans", "WAS": "Commanders"
        ]
        
        return teamNames[team] ?? team
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            CompactScoreboardView(teams: ["KC", "WAS"], scores: ["KC": 3, "WAS": 2], questionNumber: 3)
                .padding()
            CompactScoreboardView(teams: ["KC", "WAS"], scores: ["KC": 5, "WAS": 4], questionNumber: 8)
                .padding()
        }
    }
}
