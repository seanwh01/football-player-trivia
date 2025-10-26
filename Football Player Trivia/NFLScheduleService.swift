//
//  NFLScheduleService.swift
//  Football Player Trivia
//
//  Service to fetch NFL schedule data from ESPN API
//

import Foundation

struct NFLGame: Codable {
    let homeTeam: String
    let awayTeam: String
    let date: Date
    let gameId: String
}

class NFLScheduleService {
    static let shared = NFLScheduleService()
    
    private init() {}
    
    // Team abbreviation mapping: Our DB format -> ESPN format
    private let dbToEspnMapping: [String: String] = [
        "BUF": "BUF", "MIA": "MIA", "NE": "NE", "NYJ": "NYJ",
        "BAL": "BAL", "CIN": "CIN", "CLE": "CLE", "PIT": "PIT",
        "HOU": "HOU", "IND": "IND", "JAX": "JAX", "TEN": "TEN",
        "DEN": "DEN", "KC": "KC", "LAC": "LAC", "LV": "LV",
        "DAL": "DAL", "NYG": "NYG", "PHI": "PHI", "WAS": "WSH",
        "CHI": "CHI", "DET": "DET", "GB": "GB", "MIN": "MIN",
        "ATL": "ATL", "CAR": "CAR", "NO": "NO", "TB": "TB",
        "ARI": "ARI", "LA": "LAR", "SF": "SF", "SEA": "SEA"
    ]
    
    // Reverse mapping: ESPN format -> Our DB format
    private let espnToDbMapping: [String: String] = [
        "BUF": "BUF", "MIA": "MIA", "NE": "NE", "NYJ": "NYJ",
        "BAL": "BAL", "CIN": "CIN", "CLE": "CLE", "PIT": "PIT",
        "HOU": "HOU", "IND": "IND", "JAX": "JAX", "TEN": "TEN",
        "DEN": "DEN", "KC": "KC", "LAC": "LAC", "LV": "LV",
        "DAL": "DAL", "NYG": "NYG", "PHI": "PHI", "WSH": "WAS",
        "CHI": "CHI", "DET": "DET", "GB": "GB", "MIN": "MIN",
        "ATL": "ATL", "CAR": "CAR", "NO": "NO", "TB": "TB",
        "ARI": "ARI", "LAR": "LA", "SF": "SF", "SEA": "SEA"
    ]
    
    /// Fetch the next game for a specific team
    func getNextGame(for team: String, completion: @escaping (Result<NFLGame?, Error>) -> Void) {
        // Get current season year
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // Convert our DB team format to ESPN format
        let espnTeam = dbToEspnMapping[team] ?? team
        
        print("🏈 Fetching schedule for team: \(team) (ESPN: \(espnTeam))")
        
        // ESPN API endpoint for NFL team schedule
        let urlString = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/\(espnTeam)/schedule?season=\(currentYear)"
        
        print("🌐 API URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            completion(.failure(NSError(domain: "NFLScheduleService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "NFLScheduleService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            print("✅ Received \(data.count) bytes of data")
            
            do {
                // Parse JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let events = json["events"] as? [[String: Any]] {
                    
                    print("📅 Found \(events.count) total events in schedule")
                    
                    // Get current calendar date (without time)
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    var upcomingGames: [NFLGame] = []
                    
                    print("📆 Today's date (start of day): \(today)")
                    
                    for event in events {
                        // Extract competition data
                        if let competitions = event["competitions"] as? [[String: Any]],
                           let competition = competitions.first,
                           let competitors = competition["competitors"] as? [[String: Any]],
                           let dateString = competition["date"] as? String {
                            
                            // Parse date - ESPN uses format like "2025-10-28T00:15Z" (no seconds)
                            let isoFormatter = ISO8601DateFormatter()
                            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            
                            var gameDate: Date?
                            
                            // Try with fractional seconds first
                            gameDate = isoFormatter.date(from: dateString)
                            
                            // If that fails, try without fractional seconds
                            if gameDate == nil {
                                isoFormatter.formatOptions = [.withInternetDateTime]
                                gameDate = isoFormatter.date(from: dateString)
                            }
                            
                            // If still fails, try manual parsing
                            if gameDate == nil {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
                                dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                                gameDate = dateFormatter.date(from: dateString)
                            }
                            
                            guard let gameDate = gameDate else {
                                print("⚠️ Could not parse date: \(dateString)")
                                continue
                            }
                            
                            // Get game calendar date (without time)
                            let gameDateOnly = calendar.startOfDay(for: gameDate)
                            
                            print("🗓️ Game date: \(gameDateOnly), comparing to today: \(today), is past? \(gameDateOnly < today)")
                            
                            // Only include games from today or future days
                            // This means a 1pm game on 10/26 is still valid at 4pm on 10/26
                            if gameDateOnly < today {
                                print("⏭️ Skipping past game from \(gameDateOnly)")
                                continue
                            }
                            
                            // Extract teams
                            var homeTeamAbbr: String?
                            var awayTeamAbbr: String?
                            
                            for competitor in competitors {
                                if let homeAway = competitor["homeAway"] as? String,
                                   let teamData = competitor["team"] as? [String: Any],
                                   let abbreviation = teamData["abbreviation"] as? String {
                                    
                                    // Convert ESPN format to our DB format
                                    let mappedTeam = self.espnToDbMapping[abbreviation] ?? abbreviation
                                    
                                    if homeAway == "home" {
                                        homeTeamAbbr = mappedTeam
                                    } else {
                                        awayTeamAbbr = mappedTeam
                                    }
                                }
                            }
                            
                            // Create game if we have both teams
                            if let homeTeam = homeTeamAbbr,
                               let awayTeam = awayTeamAbbr,
                               let id = event["id"] as? String {
                                
                                let game = NFLGame(
                                    homeTeam: homeTeam,
                                    awayTeam: awayTeam,
                                    date: gameDate,
                                    gameId: id
                                )
                                upcomingGames.append(game)
                            }
                        }
                    }
                    
                    // Sort by date and return the next game
                    let nextGame = upcomingGames.sorted { $0.date < $1.date }.first
                    
                    if let game = nextGame {
                        print("✅ Found upcoming game: \(game.awayTeam) @ \(game.homeTeam) on \(game.date)")
                    } else {
                        print("⚠️ No upcoming games found (found \(upcomingGames.count) total upcoming games)")
                    }
                    
                    completion(.success(nextGame))
                    
                } else {
                    completion(.failure(NSError(domain: "NFLScheduleService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])))
                }
                
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
}
