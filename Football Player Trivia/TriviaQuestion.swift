//
//  TriviaQuestion.swift
//  Football Player Trivia
//
//  Represents a trivia question with player and game info
//

import Foundation

struct TriviaQuestion: Codable, Identifiable {
    let id: UUID
    let playerFirstName: String
    let playerLastName: String
    let position: String
    let team: String
    let year: Int
    let imageURL: String?
    let hintText: String?
    
    init(id: UUID = UUID(), playerFirstName: String, playerLastName: String, position: String, team: String, year: Int, imageURL: String? = nil, hintText: String? = nil) {
        self.id = id
        self.playerFirstName = playerFirstName
        self.playerLastName = playerLastName
        self.position = position
        self.team = team
        self.year = year
        self.imageURL = imageURL
        self.hintText = hintText
    }
    
    var fullPlayerName: String {
        "\(playerFirstName) \(playerLastName)"
    }
    
    var questionText: String {
        "Which \(position) played for the \(team) in \(year)?"
    }
}
