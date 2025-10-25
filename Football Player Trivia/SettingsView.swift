//
//  SettingsView.swift
//  Football Player Trivia
//
//  Settings screen with team/position configuration
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: GameSettings
    @Environment(\.presentationMode) var presentationMode
    
    @State private var originalPositions: Set<String> = []
    @State private var originalYearFrom: Int = 2016
    @State private var originalYearTo: Int = 2025
    @State private var originalTeams: Set<String> = []
    
    @State private var isUpdating2025 = false
    @State private var updateMessage = ""
    @State private var showUpdateAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var bannerAdRefreshTrigger: Int = 0
    
    @StateObject private var adManager = AdMobManager.shared
    
    var body: some View {
        ZStack {
            // Background - Football field image
            GeometryReader { geometry in
                Image("FootballFieldBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.4))
            }
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Game Experience Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Game Experience")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        Toggle(isOn: $settings.spinHapticsEnabled) {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundColor(.white)
                                Text("Spin Haptics")
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(.orange)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        Text("Enable haptic feedback when spinning wheels")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                        
                        // Sound Toggle - COMMENTED OUT
//                        Toggle(isOn: $settings.soundEnabled) {
//                            HStack {
//                                Image(systemName: "speaker.wave.2.fill")
//                                    .foregroundColor(.white)
//                                Text("Welcome Sound")
//                                    .foregroundColor(.white)
//                            }
//                        }
//                        .tint(.orange)
//                        .padding(.horizontal)
//                        .padding(.vertical, 8)
//                        .background(Color.black.opacity(0.5))
//                        .cornerRadius(10)
//                        .padding(.horizontal)
//
//                        Text("Play whistle sound when app launches")
//                            .font(.caption)
//                            .foregroundColor(.white.opacity(0.8))
//                            .padding(.horizontal, 20)
                        
                        // Hint Level Picker
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.white)
                                Text("Hint Level")
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $settings.hintLevel) {
                                    ForEach(settings.hintLevelOptions, id: \.self) { level in
                                        Text(level).tag(level)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(.white)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            
                            Text(settings.hintLevel == "More Obvious" ? "Hints include player initials" : "General clues about the player")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    // Positions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Positions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(settings.allPositions, id: \.self) { position in
                            Toggle(isOn: Binding(
                                get: { settings.selectedPositions.contains(position) },
                                set: { isSelected in
                                    if isSelected {
                                        settings.selectedPositions.insert(position)
                                    } else if settings.selectedPositions.count > 1 {
                                        settings.selectedPositions.remove(position)
                                    }
                                }
                            )) {
                                Text(position)
                                    .foregroundColor(.white)
                            }
                            .tint(.orange)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Year Range Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Year Range")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        HStack(spacing: 8) {
                            Text("From:")
                                .foregroundColor(.white)
                                .font(.system(size: 15))
                                .frame(minWidth: 45, alignment: .trailing)
                            
                            Picker("From", selection: $settings.yearFrom) {
                                ForEach(2016...2025, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(.white)
                            .frame(maxWidth: .infinity)
                            
                            Text("To:")
                                .foregroundColor(.white)
                                .font(.system(size: 15))
                                .frame(minWidth: 30, alignment: .trailing)
                            
                            Picker("To", selection: $settings.yearTo) {
                                ForEach(2016...2025, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(.white)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Data Update Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2025 Season Data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        Button(action: {
                            update2025Data()
                        }) {
                            HStack {
                                Image(systemName: isUpdating2025 ? "arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
                                    .foregroundColor(.white)
                                    .rotationEffect(isUpdating2025 ? .degrees(360) : .degrees(0))
                                    .animation(isUpdating2025 ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isUpdating2025)
                                Text(isUpdating2025 ? "Updating..." : "Update 2025 Data")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(isUpdating2025 ? Color.gray.opacity(0.5) : Color.green.opacity(0.7))
                            .cornerRadius(10)
                        }
                        .disabled(isUpdating2025)
                        .padding(.horizontal)
                        
                        Text("Download the latest snap count data for the 2025 season")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                    }
                    
                    // Teams Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Teams")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        // Quick Select Buttons
                        HStack(spacing: 10) {
                            Button(action: {
                                if settings.isAllAFCSelected {
                                    settings.deselectAllAFC()
                                } else {
                                    settings.selectAllAFC()
                                }
                            }) {
                                Text(settings.isAllAFCSelected ? "Deselect AFC" : "Select All AFC")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                if settings.isAllNFCSelected {
                                    settings.deselectAllNFC()
                                } else {
                                    settings.selectAllNFC()
                                }
                            }) {
                                Text(settings.isAllNFCSelected ? "Deselect NFC" : "Select All NFC")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        // AFC East
                        conferenceSection(title: "AFC East", teams: settings.afcEastTeams)
                        
                        // AFC North
                        conferenceSection(title: "AFC North", teams: settings.afcNorthTeams)
                        
                        // AFC South
                        conferenceSection(title: "AFC South", teams: settings.afcSouthTeams)
                        
                        // AFC West
                        conferenceSection(title: "AFC West", teams: settings.afcWestTeams)
                        
                        // NFC East
                        conferenceSection(title: "NFC East", teams: settings.nfcEastTeams)
                        
                        // NFC North
                        conferenceSection(title: "NFC North", teams: settings.nfcNorthTeams)
                        
                        // NFC South
                        conferenceSection(title: "NFC South", teams: settings.nfcSouthTeams)
                        
                        // NFC West
                        conferenceSection(title: "NFC West", teams: settings.nfcWestTeams)
                    }
                    
                    // Banner Ad
                    if bannerAdRefreshTrigger > 0 {
                        BannerAdContainer(
                            adUnitID: adManager.getBannerAdUnitID(),
                            refreshTrigger: $bannerAdRefreshTrigger
                        )
                        .padding(.top, 20)
                        .transition(.opacity)
                    }
                    
                    // Data Attribution
                    VStack(spacing: 4) {
                        Text("Data courtesy of the nflverse project")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Link("(https://github.com/nflverse)", destination: URL(string: "https://github.com/nflverse")!)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Text("used under the MIT License.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if validateSettings() {
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        showValidationAlert = true
                    }
                }) {
                    Text("Save Settings")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Restore original settings
                    settings.selectedPositions = originalPositions
                    settings.yearFrom = originalYearFrom
                    settings.yearTo = originalYearTo
                    settings.selectedTeams = originalTeams
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("2025 Data Update", isPresented: $showUpdateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(updateMessage)
        }
        .alert("Invalid Settings", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .onAppear {
            // Save original settings
            originalPositions = settings.selectedPositions
            originalYearFrom = settings.yearFrom
            originalYearTo = settings.yearTo
            originalTeams = settings.selectedTeams
            
            // Trigger banner ad to load
            bannerAdRefreshTrigger += 1
        }
    }
    
    // MARK: - Validation
    
    private func validateSettings() -> Bool {
        let positionCount = settings.selectedPositions.count
        let yearCount = settings.yearTo - settings.yearFrom + 1
        let teamCount = settings.selectedTeams.count
        
        // Check if all three have only one option
        if positionCount == 1 && yearCount == 1 && teamCount == 1 {
            validationMessage = "Cannot have only one position, one year, AND one team selected.\n\nPlease expand at least one category to have multiple options."
            return false
        }
        
        return true
    }
    
    // MARK: - Data Update Function
    
    private func update2025Data() {
        isUpdating2025 = true
        updateMessage = ""
        
        DataUpdateService.shared.update2025Data { result in
            DispatchQueue.main.async {
                self.isUpdating2025 = false
                
                switch result {
                case .success(let message):
                    self.updateMessage = message
                    self.showUpdateAlert = true
                    
                    // Reload database
                    _ = DatabaseManager.shared
                    
                case .failure(let error):
                    self.updateMessage = "❌ Update failed: \(error.localizedDescription)"
                    self.showUpdateAlert = true
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    // Helper view for conference sections
    @ViewBuilder
    private func conferenceSection(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                ForEach(teams, id: \.self) { team in
                    teamButton(team)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func teamButton(_ team: String) -> some View {
        Button(action: {
            if settings.selectedTeams.contains(team) {
                if settings.selectedTeams.count > 1 {
                    settings.selectedTeams.remove(team)
                }
            } else {
                settings.selectedTeams.insert(team)
            }
        }) {
            Text(team)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 60, height: 40)
                .background(settings.selectedTeams.contains(team) ? Color.orange.opacity(0.9) : Color.black.opacity(0.4))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(settings.selectedTeams.contains(team) ? Color.orange : Color.white.opacity(0.3), lineWidth: settings.selectedTeams.contains(team) ? 2 : 1)
                )
        }
    }
}

#Preview {
    NavigationView {
        SettingsView(settings: GameSettings())
    }
}
