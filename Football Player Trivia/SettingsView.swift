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
                        
                        // Sound Toggle
                        Toggle(isOn: $settings.soundEnabled) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.white)
                                Text("Welcome Sound")
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(.orange)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        
                        Text("Play whistle sound when app launches")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                        
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
                        
                        HStack {
                            Text("From:")
                                .foregroundColor(.white)
                            Picker("From", selection: $settings.yearFrom) {
                                ForEach(2016...2024, id: \.self) { year in
                                    Text(String(year)).tag(year)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(.white)
                            
                            Text("To:")
                                .foregroundColor(.white)
                            Picker("To", selection: $settings.yearTo) {
                                ForEach(2016...2024, id: \.self) { year in
                                    Text(String(year)).tag(year)
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
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
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
