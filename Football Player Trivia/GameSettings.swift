//
//  GameSettings.swift
//  Football Trivia
//
//  Game settings and configuration management
//

import Foundation
import Combine

class GameSettings: ObservableObject {
    // UserDefaults keys
    private let selectedPositionsKey = "selectedPositions"
    private let yearFromKey = "yearFrom"
    private let yearToKey = "yearTo"
    private let selectedTeamsKey = "selectedTeams"
    private let spinHapticsEnabledKey = "spinHapticsEnabled"
    private let hintLevelKey = "hintLevel"
    private let soundEnabledKey = "soundEnabled"
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var selectedPositions: Set<String> = [
        "Quarterback",
        "Running Back",
        "Wide Receiver",
        "Tight End",
        "Linebacker",
        "Cornerback",
        "Safety",
        "Defensive Line"
    ]
    
    @Published var yearFrom: Int = 2016
    @Published var yearTo: Int = 2024
    
    @Published var sessionCorrect: Int = 0
    @Published var sessionTotal: Int = 0
    @Published var sessionHintCount: Int = 0
    
    @Published var spinHapticsEnabled: Bool = true
    @Published var hintLevel: String = "General"
    @Published var soundEnabled: Bool = true
    
    @Published var selectedTeams: Set<String> = []
    
    let allPositions = [
        "Quarterback",
        "Running Back",
        "Wide Receiver",
        "Tight End",
        "Linebacker",
        "Cornerback",
        "Safety",
        "Defensive Line"
    ]
    
    let hintLevelOptions = ["General", "More Obvious"]
    
    // NFL Teams (2016-2024)
    let afcEastTeams = ["BUF", "MIA", "NE", "NYJ"]
    let afcNorthTeams = ["BAL", "CIN", "CLE", "PIT"]
    let afcSouthTeams = ["HOU", "IND", "JAX", "TEN"]
    let afcWestTeams = ["DEN", "KC", "LAC", "LV"]
    
    let nfcEastTeams = ["DAL", "NYG", "PHI", "WAS"]
    let nfcNorthTeams = ["CHI", "DET", "GB", "MIN"]
    let nfcSouthTeams = ["ATL", "CAR", "NO", "TB"]
    let nfcWestTeams = ["ARI", "LA", "SF", "SEA"]
    
    var allTeams: [String] {
        return afcEastTeams + afcNorthTeams + afcSouthTeams + afcWestTeams +
               nfcEastTeams + nfcNorthTeams + nfcSouthTeams + nfcWestTeams
    }
    
    var afcTeams: [String] {
        return afcEastTeams + afcNorthTeams + afcSouthTeams + afcWestTeams
    }
    
    var nfcTeams: [String] {
        return nfcEastTeams + nfcNorthTeams + nfcSouthTeams + nfcWestTeams
    }
    
    init() {
        // Default: all teams selected
        selectedTeams = Set(allTeams)
        
        // Load saved settings
        loadSettings()
        
        // Setup observers to save when settings change
        setupObservers()
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        if let savedPositions = UserDefaults.standard.array(forKey: selectedPositionsKey) as? [String] {
            selectedPositions = Set(savedPositions)
        }
        
        let savedYearFrom = UserDefaults.standard.integer(forKey: yearFromKey)
        if savedYearFrom != 0 {
            yearFrom = savedYearFrom
        }
        
        let savedYearTo = UserDefaults.standard.integer(forKey: yearToKey)
        if savedYearTo != 0 {
            yearTo = savedYearTo
        }
        
        if let savedTeams = UserDefaults.standard.array(forKey: selectedTeamsKey) as? [String] {
            selectedTeams = Set(savedTeams)
        }
        
        if UserDefaults.standard.object(forKey: spinHapticsEnabledKey) != nil {
            spinHapticsEnabled = UserDefaults.standard.bool(forKey: spinHapticsEnabledKey)
        }
        
        if let savedHintLevel = UserDefaults.standard.string(forKey: hintLevelKey) {
            hintLevel = savedHintLevel
        }
        
        if UserDefaults.standard.object(forKey: soundEnabledKey) != nil {
            soundEnabled = UserDefaults.standard.bool(forKey: soundEnabledKey)
        }
        
        print("✅ Settings loaded from UserDefaults")
    }
    
    private func setupObservers() {
        $selectedPositions
            .dropFirst()
            .sink { [weak self] positions in
                UserDefaults.standard.set(Array(positions), forKey: self?.selectedPositionsKey ?? "")
            }
            .store(in: &cancellables)
        
        $yearFrom
            .dropFirst()
            .sink { [weak self] year in
                UserDefaults.standard.set(year, forKey: self?.yearFromKey ?? "")
            }
            .store(in: &cancellables)
        
        $yearTo
            .dropFirst()
            .sink { [weak self] year in
                UserDefaults.standard.set(year, forKey: self?.yearToKey ?? "")
            }
            .store(in: &cancellables)
        
        $selectedTeams
            .dropFirst()
            .sink { [weak self] teams in
                UserDefaults.standard.set(Array(teams), forKey: self?.selectedTeamsKey ?? "")
            }
            .store(in: &cancellables)
        
        $spinHapticsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                UserDefaults.standard.set(enabled, forKey: self?.spinHapticsEnabledKey ?? "")
            }
            .store(in: &cancellables)
        
        $hintLevel
            .dropFirst()
            .sink { [weak self] level in
                UserDefaults.standard.set(level, forKey: self?.hintLevelKey ?? "")
            }
            .store(in: &cancellables)
        
        $soundEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                UserDefaults.standard.set(enabled, forKey: self?.soundEnabledKey ?? "")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    func getTeamsForYear(_ year: Int) -> [String] {
        let teamsInYear = DatabaseManager.shared.getTeamsForYear(year)
        return selectedTeams.filter { teamsInYear.contains($0) }.sorted()
    }
    
    func teamExistsInRange(_ team: String) -> Bool {
        return DatabaseManager.shared.teamExistsInYearRange(team: team, from: yearFrom, to: yearTo)
    }
    
    func getAvailablePositions() -> [String] {
        return Array(selectedPositions).sorted()
    }
    
    func getAvailableYears() -> [String] {
        return (yearFrom...yearTo).map { String($0) }.reversed()
    }
    
    func getAvailableTeams() -> [String] {
        return Array(selectedTeams).sorted()
    }
    
    // Quick select helpers
    var isAllAFCSelected: Bool {
        afcTeams.allSatisfy { selectedTeams.contains($0) }
    }
    
    var isAllNFCSelected: Bool {
        nfcTeams.allSatisfy { selectedTeams.contains($0) }
    }
    
    func selectAllAFC() {
        afcTeams.forEach { selectedTeams.insert($0) }
    }
    
    func deselectAllAFC() {
        afcTeams.forEach { selectedTeams.remove($0) }
        if selectedTeams.isEmpty && !nfcTeams.isEmpty {
            selectedTeams.insert(nfcTeams[0])
        }
    }
    
    func selectAllNFC() {
        nfcTeams.forEach { selectedTeams.insert($0) }
    }
    
    func deselectAllNFC() {
        nfcTeams.forEach { selectedTeams.remove($0) }
        if selectedTeams.isEmpty && !afcTeams.isEmpty {
            selectedTeams.insert(afcTeams[0])
        }
    }
}
