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
        case "QB":
            positionDescription = "the top quarterback"
        case "RB":
            positionDescription = "one of the top two running backs"
        case "WR":
            positionDescription = "one of the top three wide receivers"
        case "TE":
            positionDescription = "the top Tight End"
        case "OL":
            positionDescription = "one of the top five offensive linemen"
        case "DL":
            positionDescription = "one of the top three defensive linemen"
        case "LB":
            positionDescription = "one of the top three linebackers"
        case "DB":
            positionDescription = "one of the top four defensive backs"
        case "K":
            positionDescription = "the kicker"
        default:
            positionDescription = "the \(position)"
        }
        
        return "Name \(positionDescription) for \(team) in \(year)."
    }
}
