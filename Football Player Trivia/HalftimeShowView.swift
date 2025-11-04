//
//  HalftimeShowView.swift
//  Football Player Trivia
//
//  Halftime show with TV scoreboard
//

import SwiftUI
import AVFoundation

struct HalftimeShowView: View {
    let teams: [String]
    let scores: [String: Int]
    let onContinue: () -> Void
    
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        ZStack {
            // Background Image
            Image("HalftimePic")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: 100)
                
                // Classic Scoreboard
                VStack(spacing: 0) {
                    // Teams and Scores
                    ForEach(Array(teams.enumerated()), id: \.element) { index, team in
                        HStack {
                            // Team Name
                            Text(team)
                                .font(.system(size: 60, weight: .black))
                                .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.82))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 30)
                            
                            // Score
                            Text("\(scores[team] ?? 0)")
                                .font(.system(size: 80, weight: .black))
                                .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.82))
                                .padding(.trailing, 30)
                        }
                        .padding(.vertical, 25)
                        .background(Color.black)
                        
                        // Divider between teams
                        if index == 0 {
                            Rectangle()
                                .fill(Color(red: 0.95, green: 0.92, blue: 0.82))
                                .frame(height: 3)
                        }
                    }
                }
                .background(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color(red: 0.8, green: 0.6, blue: 0.2), lineWidth: 8)
                )
                .shadow(color: Color.black.opacity(0.7), radius: 20, x: 0, y: 10)
                .frame(width: 340)
                
                // HALFTIME Text
                Text("HALFTIME")
                    .font(.system(size: 70, weight: .black))
                    .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.82))
                    .shadow(color: Color.black.opacity(0.5), radius: 5, x: 0, y: 3)
                
                Spacer()
                
                // Continue button at bottom
                Button(action: onContinue) {
                    Text("Continue Game")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 18)
                        .background(Color.green)
                        .cornerRadius(15)
                        .shadow(color: Color.green.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            playHalftimeMusic()
        }
        .onDisappear {
            stopHalftimeMusic()
        }
    }
    
    private func playHalftimeMusic() {
        guard let url = Bundle.main.url(forResource: "Halftime", withExtension: "mp3") else {
            print("⚠️ Halftime.mp3 not found")
            return
        }
        
        do {
            // Use .ambient category to respect the mute switch
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 0 // Play once
            audioPlayer?.volume = 0.5
            audioPlayer?.play()
            print("🎵 Playing halftime music")
        } catch {
            print("❌ Error playing halftime music: \(error.localizedDescription)")
        }
    }
    
    private func stopHalftimeMusic() {
        audioPlayer?.stop()
        audioPlayer = nil
        print("🔇 Stopped halftime music")
    }
}

#Preview {
    HalftimeShowView(
        teams: ["KC", "WAS"],
        scores: ["KC": 5, "WAS": 4],
        onContinue: {}
    )
}
