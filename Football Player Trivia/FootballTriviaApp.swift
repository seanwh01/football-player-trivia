//
//  FootballTriviaApp.swift
//  Football Trivia
//
//  Main app entry point with Firebase and AdMob initialization
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds

@main
struct FootballTriviaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        print("✅ Firebase initialized successfully")
        
        // Initialize AdMob SDK (Swift API):
                MobileAds.shared.start()
        // Delay AdMob initialization to avoid blocking app launch
        // AdMob will start when first ad is loaded (lazy initialization)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            MobileAds.shared.start { status in
                print("✅ AdMob initialized successfully (delayed)")
                print("   Adapter statuses: \(status.adapterStatusesByClassName)")
            }
        }
        
        // Warm up database on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            _ = DatabaseManager.shared
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// App Delegate to enforce portrait orientation
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // Force portrait orientation
        // iPhone: Portrait only
        // iPad: Portrait and upside-down
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [.portrait, .portraitUpsideDown]
        } else {
            return .portrait
        }
    }
}
