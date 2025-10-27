//
//  MultiplayerHostSetupView.swift
//  Football Player Trivia
//
//  Host setup screen for multiplayer trivia game
//

import SwiftUI

struct MultiplayerHostSetupView: View {
    @ObservedObject var settings: GameSettings
    @StateObject private var multiplayerManager = MultiplayerManager()
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isNameFieldFocused: Bool
    @Binding var isPresented: Bool
    
    @State private var hostName = ""
    @State private var selectedPositions: Set<String> = []
    @State private var selectedTeams: Set<String> = []
    @State private var yearFrom = 2024
    @State private var yearTo = 2024
    @State private var questionCount = 12
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToLobby = false
    
    let questionOptions = [8, 12, 24]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.95)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Title
                        Text("Host Multiplayer Game")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        // Host Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Name")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            TextField("Enter your name", text: $hostName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .focused($isNameFieldFocused)
                        }
                        .padding(.horizontal)
                        
                        // Question Count Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Number of Questions")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            HStack(spacing: 12) {
                                ForEach(questionOptions, id: \.self) { count in
                                    Button(action: {
                                        questionCount = count
                                    }) {
                                        Text("\(count)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(questionCount == count ? Color.green : Color.gray.opacity(0.3))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Year Range
                        yearRangeSection
                        
                        // Positions
                        positionsSection
                        
                        // Teams
                        teamsSection
                        
                        // Validation message
                        if !isValidSelection {
                            Text("⚠️ At least one category (Positions, Teams, or Years) must have multiple selections")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Host Game Button
                        Button(action: startHosting) {
                            Text("Host Game")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canStartHosting ? Color.green : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!canStartHosting)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
                
                // Navigation to lobby
                NavigationLink(
                    destination: MultiplayerLobbyView(multiplayerManager: multiplayerManager, isPresented: $isPresented),
                    isActive: $navigateToLobby
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            // Initialize with current settings
            selectedPositions = settings.selectedPositions
            selectedTeams = settings.selectedTeams
            yearFrom = settings.yearFrom
            yearTo = settings.yearTo
            
            // Auto-focus name field
            isNameFieldFocused = true
        }
    }
    
    // MARK: - Year Range Section
    
    private var yearRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year Range")
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Text("From")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("From", selection: $yearFrom) {
                        ForEach(2016...2025, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(.white)
                    .onChange(of: yearFrom) { newValue in
                        if newValue > yearTo {
                            yearTo = newValue
                        }
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Text("To")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 60, alignment: .leading)
                    
                    Picker("To", selection: $yearTo) {
                        ForEach(2016...2025, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(.white)
                    .onChange(of: yearTo) { newValue in
                        if newValue < yearFrom {
                            yearFrom = newValue
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Positions Section
    
    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Positions")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Spacer()
                
                Button(selectedPositions.count == settings.allPositions.count ? "Deselect All" : "Select All") {
                    if selectedPositions.count == settings.allPositions.count {
                        selectedPositions.removeAll()
                    } else {
                        selectedPositions = Set(settings.allPositions)
                    }
                }
                .font(.caption)
                .foregroundColor(.green)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(settings.allPositions, id: \.self) { position in
                    positionButton(position)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func positionButton(_ position: String) -> some View {
        Button(action: {
            if selectedPositions.contains(position) {
                selectedPositions.remove(position)
            } else {
                selectedPositions.insert(position)
            }
        }) {
            Text(position)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedPositions.contains(position) ? Color.green.opacity(0.8) : Color.white.opacity(0.2))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Teams Section
    
    private var teamsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Teams")
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.horizontal)
            
            // AFC Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("AFC")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(selectedTeams.intersection(Set(afcTeams)).count == afcTeams.count ? "Deselect All" : "Select All") {
                        if selectedTeams.intersection(Set(afcTeams)).count == afcTeams.count {
                            selectedTeams.subtract(afcTeams)
                        } else {
                            selectedTeams.formUnion(afcTeams)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                }
                .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(afcTeams, id: \.self) { team in
                        teamButton(team)
                    }
                }
                .padding(.horizontal)
            }
            
            // NFC Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("NFC")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(selectedTeams.intersection(Set(nfcTeams)).count == nfcTeams.count ? "Deselect All" : "Select All") {
                        if selectedTeams.intersection(Set(nfcTeams)).count == nfcTeams.count {
                            selectedTeams.subtract(nfcTeams)
                        } else {
                            selectedTeams.formUnion(nfcTeams)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                }
                .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(nfcTeams, id: \.self) { team in
                        teamButton(team)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func teamButton(_ team: String) -> some View {
        Button(action: {
            if selectedTeams.contains(team) {
                selectedTeams.remove(team)
            } else {
                selectedTeams.insert(team)
            }
        }) {
            Text(team)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTeams.contains(team) ? Color.green.opacity(0.8) : Color.white.opacity(0.2))
                .cornerRadius(6)
        }
    }
    
    // MARK: - Computed Properties
    
    private var afcTeams: [String] {
        settings.afcEastTeams + settings.afcNorthTeams + settings.afcSouthTeams + settings.afcWestTeams
    }
    
    private var nfcTeams: [String] {
        settings.nfcEastTeams + settings.nfcNorthTeams + settings.nfcSouthTeams + settings.nfcWestTeams
    }
    
    private var allTeams: [String] {
        afcTeams + nfcTeams
    }
    
    private var isValidSelection: Bool {
        let hasMultiplePositions = selectedPositions.count > 1
        let hasMultipleTeams = selectedTeams.count > 1
        let hasMultipleYears = yearFrom != yearTo
        
        return hasMultiplePositions || hasMultipleTeams || hasMultipleYears
    }
    
    private var canStartHosting: Bool {
        !hostName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedPositions.isEmpty &&
        !selectedTeams.isEmpty &&
        isValidSelection
    }
    
    // MARK: - Actions
    
    private func startHosting() {
        let gameSettings = MultiplayerGameSettings(
            positions: Array(selectedPositions),
            teams: Array(selectedTeams),
            yearFrom: yearFrom,
            yearTo: yearTo,
            questionCount: questionCount
        )
        
        multiplayerManager.startHosting(playerName: hostName, settings: gameSettings)
        navigateToLobby = true
    }
}

#Preview {
    MultiplayerHostSetupView(settings: GameSettings(), isPresented: .constant(true))
}
