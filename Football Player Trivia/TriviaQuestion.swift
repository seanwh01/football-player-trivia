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
        let positionDescription: String
        
        switch position {
        case "QB", "Quarterback":
            positionDescription = "the top quarterback"
        case "RB", "Running Back":
            positionDescription = "one of the top two running backs"
        case "WR", "Wide Receiver":
            positionDescription = "one of the top three wide receivers"
        case "TE", "Tight End":
            positionDescription = "the top Tight End"
        case "OL", "Offensive Linemen":
            positionDescription = "one of the top five offensive linemen"
        case "DL", "Defensive Linemen":
            positionDescription = "one of the top three defensive linemen"
        case "LB", "Linebacker":
            positionDescription = "one of the top three linebackers"
        case "DB", "Defensive Back":
            positionDescription = "one of the top four defensive backs"
        case "K", "Kicker":
            positionDescription = "the kicker"
        default:
            positionDescription = "the \(position)"
        }
        
        return "Name \(positionDescription) for \(team) in \(year)."
    }
}
