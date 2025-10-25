//
//  DataUpdateService.swift
//  Football Player Trivia
//
//  Service to download and update 2025 season data
//

import Foundation
import SQLite3

class DataUpdateService {
    static let shared = DataUpdateService()
    
    // nflverse 2025 snap counts data (per-game, will be aggregated)
    private let dataURL = "https://github.com/nflverse/nflverse-data/releases/download/snap_counts/snap_counts_2025.csv"
    
    private init() {}
    
    /// Download and update 2025 season data
    func update2025Data(completion: @escaping (Result<String, Error>) -> Void) {
        print("📥 Starting 2025 data update...")
        
        guard let url = URL(string: dataURL) else {
            completion(.failure(NSError(domain: "DataUpdateService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Download error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let csvString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "DataUpdateService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid data format"])))
                return
            }
            
            print("✅ Downloaded \(data.count) bytes")
            
            // Parse and update database
            do {
                try self.updateDatabase(with: csvString)
                let message = "✅ 2025 data updated successfully!"
                print(message)
                completion(.success(message))
            } catch {
                print("❌ Database update error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Parse CSV and update database
    private func updateDatabase(with csvString: String) throws {
        guard let dbPath = Bundle.main.path(forResource: "football", ofType: "db") else {
            throw NSError(domain: "DataUpdateService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Database not found"])
        }
        
        // Since the bundled DB is read-only, we need to use the Documents directory copy
        // First check if we have a writable copy
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let writableDBPath = documentsURL.appendingPathComponent("football.db").path
        
        // Copy from bundle to Documents if needed
        if !fileManager.fileExists(atPath: writableDBPath) {
            try fileManager.copyItem(atPath: dbPath, toPath: writableDBPath)
            print("📋 Copied database to Documents directory")
        }
        
        var db: OpaquePointer?
        guard sqlite3_open(writableDBPath, &db) == SQLITE_OK else {
            throw NSError(domain: "DataUpdateService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not open database"])
        }
        
        defer {
            sqlite3_close(db)
        }
        
        // Delete existing 2025 data
        let deleteQuery = "DELETE FROM snap_counts WHERE season = 2025"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                print("🗑️ Deleted old 2025 data")
            }
        }
        sqlite3_finalize(deleteStatement)
        
        // Parse nflverse CSV (per-game) and aggregate by player
        let lines = csvString.components(separatedBy: .newlines)
        
        // Dictionary to aggregate snaps: [player_key: (id, name, team, pos, off, def, st)]
        var playerAggregates: [String: (id: String, name: String, team: String, pos: String, off: Int, def: Int, st: Int)] = [:]
        
        // Parse CSV - nflverse format: game_id,pfr_game_id,season,game_type,week,player,pfr_player_id,position,team,opponent,offense_snaps,offense_pct,defense_snaps,defense_pct,st_snaps,st_pct
        for (index, line) in lines.enumerated() {
            guard index > 0 && !line.isEmpty else { continue }
            
            let columns = line.components(separatedBy: ",")
            guard columns.count >= 16 else { continue }
            
            let playerName = columns[5].trimmingCharacters(in: .whitespaces)
            let playerId = columns[6].trimmingCharacters(in: .whitespaces)
            let position = columns[7].trimmingCharacters(in: .whitespaces)
            let team = columns[8].trimmingCharacters(in: .whitespaces)
            let offenseSnaps = Int(columns[10].trimmingCharacters(in: .whitespaces)) ?? 0
            let defenseSnaps = Int(columns[12].trimmingCharacters(in: .whitespaces)) ?? 0
            let stSnaps = Int(columns[14].trimmingCharacters(in: .whitespaces)) ?? 0
            
            // Create unique key for player
            let key = "\(playerId)_\(team)"
            
            // Aggregate snaps
            if var existing = playerAggregates[key] {
                existing.off += offenseSnaps
                existing.def += defenseSnaps
                existing.st += stSnaps
                playerAggregates[key] = existing
            } else {
                playerAggregates[key] = (playerId, playerName, team, position, offenseSnaps, defenseSnaps, stSnaps)
            }
        }
        
        print("📊 Aggregated \(playerAggregates.count) unique players")
        
        // Insert aggregated data
        let insertQuery = """
            INSERT INTO snap_counts (player_id, player_name, season, team, position, offense_snaps, defense_snaps, st_snaps)
            VALUES (?, ?, 2025, ?, ?, ?, ?, ?)
        """
        var insertStatement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK else {
            throw NSError(domain: "DataUpdateService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not prepare insert statement"])
        }
        
        var insertedCount = 0
        for (_, player) in playerAggregates {
            sqlite3_bind_text(insertStatement, 1, (player.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (player.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (player.team as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, (player.pos as NSString).utf8String, -1, nil)
            sqlite3_bind_int(insertStatement, 5, Int32(player.off))
            sqlite3_bind_int(insertStatement, 6, Int32(player.def))
            sqlite3_bind_int(insertStatement, 7, Int32(player.st))
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                insertedCount += 1
            }
            sqlite3_reset(insertStatement)
        }
        
        sqlite3_finalize(insertStatement)
        
        print("✅ Inserted \(insertedCount) player records for 2025")
        
        // Update DatabaseManager to use the new writable database path
        NotificationCenter.default.post(name: NSNotification.Name("DatabaseUpdated"), object: nil)
    }
}
