//
//  HeadToHeadSelectionView.swift
//  Football Player Trivia
//
//  Head-to-head team selection popup
//

import SwiftUI

struct HeadToHeadSelectionView: View {
    @ObservedObject var settings: GameSettings
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTeams: Set<String> = []
    @Binding var shouldNavigateToGame: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Title
                    Text("Select Two Teams")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    Text("Choose two teams for head-to-head competition")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 20)
                    
                    // Scrollable team selection
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
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
                            
                            // Bottom padding for button
                            Spacer()
                                .frame(height: 80)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Ready to Play button (fixed at bottom)
                    Button(action: {
                        startHeadToHeadGame()
                    }) {
                        Text("Ready to Play")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedTeams.count == 2 ? Color.green : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(selectedTeams.count != 2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .background(Color.black.opacity(0.95))
                }
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
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func conferenceSection(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.orange)
                .padding(.leading, 5)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(teams, id: \.self) { team in
                    teamCheckbox(team)
                }
            }
        }
    }
    
    private func teamCheckbox(_ team: String) -> some View {
        Button(action: {
            toggleTeam(team)
        }) {
            HStack(spacing: 6) {
                Image(systemName: selectedTeams.contains(team) ? "checkmark.square.fill" : "square")
                    .foregroundColor(selectedTeams.contains(team) ? .green : .white.opacity(0.6))
                    .font(.system(size: 18))
                
                Text(team)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selectedTeams.contains(team) ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedTeams.contains(team) ? Color.green : Color.white.opacity(0.3), lineWidth: selectedTeams.contains(team) ? 2 : 1)
            )
        }
    }
    
    // MARK: - Actions
    
    private func toggleTeam(_ team: String) {
        if selectedTeams.contains(team) {
            selectedTeams.remove(team)
        } else {
            // Only allow 2 teams
            if selectedTeams.count < 2 {
                selectedTeams.insert(team)
            }
        }
    }
    
    private func startHeadToHeadGame() {
        guard selectedTeams.count == 2 else { return }
        
        // Get current year
        let currentYear = Calendar.current.component(.year, from: Date())
        
        // Configure settings for head-to-head challenge
        settings.yearFrom = currentYear
        settings.yearTo = currentYear
        settings.selectedPositions = Set(settings.allPositions)
        settings.selectedTeams = selectedTeams
        
        // Dismiss this view and trigger navigation
        presentationMode.wrappedValue.dismiss()
        
        // Small delay to ensure smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shouldNavigateToGame = true
        }
    }
}

#Preview {
    HeadToHeadSelectionView(
        settings: GameSettings(),
        shouldNavigateToGame: .constant(false)
    )
}
