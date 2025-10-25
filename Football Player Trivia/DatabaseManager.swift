//
//  DatabaseManager.swift
//  Football Trivia
//
//  Manages SQLite database queries for NFL player snap counts
//

import Foundation
import SQLite3

// Player model
struct Player {
    let playerId: String
    let playerName: String
    let firstName: String
    let lastName: String
    let position: String
    let totalSnaps: Int
}

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var db: OpaquePointer?
    
    private init() {
        openDatabase()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() {
        // Try to use writable database from Documents directory first (for 2025 updates)
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let writableDBPath = documentsURL.appendingPathComponent("football.db").path
        
        var dbPath: String
        
        // Check if writable copy exists
        if fileManager.fileExists(atPath: writableDBPath) {
            dbPath = writableDBPath
            print("📂 Using writable database from Documents directory")
        } else {
            // Use bundled database (read-only)
            guard let bundlePath = Bundle.main.path(forResource: "football", ofType: "db") else {
                print("❌ ERROR: Database file not found in bundle")
                return
            }
            dbPath = bundlePath
            print("📂 Using read-only database from bundle")
        }
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ ERROR: Unable to open database")
            return
        }
        
        print("✅ Database opened successfully")
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    // MARK: - Query Methods
    
    /// Get top player at a single-player position (QB, TE)
    func getTopPlayerAtPosition(position: String, year: Int, team: String, snapType: String = "offense") -> Player? {
        let positions = getPositionCodes(for: position)
        let positionList = positions.map { "'\($0)'" }.joined(separator: ", ")
        let snapColumn = snapType == "offense" ? "offense_snaps" : "defense_snaps"
        
        let query = """
            SELECT player_id, player_name, SUM(\(snapColumn)) as total_snaps
            FROM snap_counts
            WHERE season = ?
                AND team = ?
                AND position IN (\(positionList))
            GROUP BY player_id, player_name
            ORDER BY total_snaps DESC
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        var topPlayer: Player?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(year))
            sqlite3_bind_text(statement, 2, (team as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let playerId = String(cString: sqlite3_column_text(statement, 0))
                let playerName = String(cString: sqlite3_column_text(statement, 1))
                let totalSnaps = Int(sqlite3_column_int(statement, 2))
                
                let nameParts = playerName.split(separator: " ", maxSplits: 1)
                let firstName = nameParts.first.map(String.init) ?? ""
                let lastName = nameParts.count > 1 ? String(nameParts[1]) : ""
                
                topPlayer = Player(
                    playerId: playerId,
                    playerName: playerName,
                    firstName: firstName,
                    lastName: lastName,
                    position: position,
                    totalSnaps: totalSnaps
                )
                
                print("✅ Found top \(position): \(playerName) (\(totalSnaps) snaps)")
            }
        } else {
            print("❌ Query preparation failed")
        }
        
        sqlite3_finalize(statement)
        return topPlayer
    }
    
    /// Get top N players at a multi-player position (RB, WR, LB, etc.)
    func getTopPlayersAtPosition(position: String, year: Int, team: String, limit: Int, snapType: String = "offense") -> [Player] {
        let positions = getPositionCodes(for: position)
        let positionList = positions.map { "'\($0)'" }.joined(separator: ", ")
        let snapColumn = snapType == "offense" ? "offense_snaps" : "defense_snaps"
        
        let query = """
            SELECT player_id, player_name, SUM(\(snapColumn)) as total_snaps
            FROM snap_counts
            WHERE season = ?
                AND team = ?
                AND position IN (\(positionList))
            GROUP BY player_id, player_name
            ORDER BY total_snaps DESC
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        var players: [Player] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(year))
            sqlite3_bind_text(statement, 2, (team as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 3, Int32(limit))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let playerId = String(cString: sqlite3_column_text(statement, 0))
                let playerName = String(cString: sqlite3_column_text(statement, 1))
                let totalSnaps = Int(sqlite3_column_int(statement, 2))
                
                let nameParts = playerName.split(separator: " ", maxSplits: 1)
                let firstName = nameParts.first.map(String.init) ?? ""
                let lastName = nameParts.count > 1 ? String(nameParts[1]) : ""
                
                players.append(Player(
                    playerId: playerId,
                    playerName: playerName,
                    firstName: firstName,
                    lastName: lastName,
                    position: position,
                    totalSnaps: totalSnaps
                ))
            }
            
            print("✅ Found \(players.count) top \(position)s")
        } else {
            print("❌ Query preparation failed")
        }
        
        sqlite3_finalize(statement)
        return players
    }
    
    /// Map trivia position to database position codes
    private func getPositionCodes(for position: String) -> [String] {
        switch position {
        case "Quarterback":
            return ["QB"]
        case "Running Back":
            return ["RB", "HB", "FB"]
        case "Wide Receiver":
            return ["WR"]
        case "Tight End":
            return ["TE"]
        case "Offensive Linemen":
            return ["C", "G", "LG", "RG", "T", "LT", "RT", "OL"]
        case "Linebacker":
            return ["LB", "ILB", "MLB", "OLB"]
        case "Defensive Back":
            return ["CB", "DB", "S", "SS", "FS"]
        case "Defensive Linemen":
            return ["DE", "DT", "DL", "NT"]
        case "Placekicker":
            return ["K", "PK"]
        default:
            return []
        }
    }
    
    /// Get all teams that played in a specific year
    func getTeamsForYear(_ year: Int) -> [String] {
        let query = """
            SELECT DISTINCT team
            FROM snap_counts
            WHERE season = ?
            ORDER BY team
        """
        
        var statement: OpaquePointer?
        var teams: [String] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(year))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let team = String(cString: sqlite3_column_text(statement, 0))
                teams.append(team)
            }
        }
        
        sqlite3_finalize(statement)
        return teams
    }
    
    /// Check if team exists in year range
    func teamExistsInYearRange(team: String, from: Int, to: Int) -> Bool {
        let query = """
            SELECT COUNT(*)
            FROM snap_counts
            WHERE team = ? AND season >= ? AND season <= ?
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        var exists = false
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (team as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(from))
            sqlite3_bind_int(statement, 3, Int32(to))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                exists = sqlite3_column_int(statement, 0) > 0
            }
        }
        
        sqlite3_finalize(statement)
        return exists
    }
}
