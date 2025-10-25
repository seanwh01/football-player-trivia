//
//  ContentView.swift
//  Football Trivia
//
//  Home screen with navigation to game and settings
//

import SwiftUI
import AVFoundation
import AppTrackingTransparency
import AdSupport

struct ContentView: View {
    @StateObject private var gameSettings = GameSettings()
    @State private var audioPlayer: AVAudioPlayer?
    @State private var hasPlayedSound = false
    
    var body: some View {
        NavigationView {
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
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // App Icon/Logo
                    Image("PigskinGeniusLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 5)
                    
                    // Tagline
                    Text("Test your NFL player knowledge!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
                        .padding(.top, 10)
                    
                    Spacer()
                    Spacer()
                    
                    // Start Button
                    NavigationLink(destination: TriviaGameView(settings: gameSettings)) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Trivia")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(settings: gameSettings)) {
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                            .font(.title3)
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                requestTrackingPermission()
                playWhistleSoundOnce()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func playWhistleSoundOnce() {
        guard gameSettings.soundEnabled && !hasPlayedSound else {
            return
        }
        
        guard let soundURL = Bundle.main.url(forResource: "WhistleSound", withExtension: "m4a") else {
            print("ℹ️ WhistleSound.m4a not found - skipping sound")
            hasPlayedSound = true // Mark as played so we don't keep trying
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            hasPlayedSound = true
            print("🔊 Playing whistle sound!")
        } catch {
            print("❌ Failed to play sound: \(error.localizedDescription)")
        }
    }
    
    private func requestTrackingPermission() {
        let currentStatus = ATTrackingManager.trackingAuthorizationStatus
        print("📊 Current tracking status: \(currentStatus.rawValue)")
        
        guard currentStatus == .notDetermined else {
            print("ℹ️ Tracking already determined, skipping request")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("🔔 Requesting tracking authorization...")
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("✅ Tracking authorized - AdMob can use IDFA")
                case .denied:
                    print("⚠️ Tracking denied - AdMob will use limited ads")
                case .notDetermined:
                    print("⚠️ Tracking not determined")
                case .restricted:
                    print("⚠️ Tracking restricted")
                @unknown default:
                    print("⚠️ Unknown tracking status")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
