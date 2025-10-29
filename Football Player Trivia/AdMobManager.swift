//
//  AdMobManager.swift
//  Baseball Player Trivia
//
//  Manages Google AdMob banner and interstitial ads
//

import Foundation
import Combine
import GoogleMobileAds

@MainActor
class AdMobManager: NSObject, ObservableObject {
    static let shared = AdMobManager()
    
    // MARK: - Ad Unit IDs
    
    // TODO: Replace with YOUR REAL ad unit IDs from AdMob console
    // Get these from: https://apps.admob.com/
    // 1. Select your app
    // 2. Go to "Ad units"
    // Ad unit IDs loaded securely from AdMobKeys.plist (not tracked in Git)
    private let bannerAdUnitID = AdMobConfig.shared.getBannerAdUnitID
    private let interstitialAdUnitID = AdMobConfig.shared.getInterstitialAdUnitID
    
    // MARK: - Interstitial Ad Properties
    
    @Published var interstitialAd: InterstitialAd?
    @Published var isInterstitialReady = false
    
    // MARK: - Configuration
    
    private let hintCountForInterstitial = 4 // Show ad every 4th hint
    
    private override init() {
        super.init()
        // Don't load interstitial on init - wait until user requests first hint
    }
    
    // MARK: - Banner Ad
    
    /// Get banner ad unit ID
    func getBannerAdUnitID() -> String {
        return bannerAdUnitID
    }
    
    // MARK: - Interstitial Ad
    
    /// Load interstitial ad
    func loadInterstitialAd() {
        let request = Request()
        
        InterstitialAd.load(
            with: interstitialAdUnitID,
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
                self?.isInterstitialReady = false
                return
            }
            
            print("✅ Interstitial ad loaded successfully")
            self?.interstitialAd = ad
            self?.isInterstitialReady = true
            ad?.fullScreenContentDelegate = self
        }
    }
    
    /// Show interstitial ad if hint count threshold is reached
    func showInterstitialIfNeeded(hintCount: Int, from viewController: UIViewController) -> Bool {
        // Check if we should show ad (every Nth hint)
        guard hintCount > 0 && hintCount % hintCountForInterstitial == 0 else {
            return false
        }
        
        // Check if ad is ready
        guard let interstitial = interstitialAd, isInterstitialReady else {
            print("⚠️ Interstitial ad not ready yet")
            // Load next ad for next time
            loadInterstitialAd()
            return false
        }
        
        // Show the ad
        print("🎬 Showing interstitial ad (hint #\(hintCount))")
        interstitial.present(from: viewController)
        
        // Mark as not ready and load next ad
        isInterstitialReady = false
        
        return true
    }
    
    /// Show interstitial ad immediately (without hint count check)
    func showInterstitialAd(from viewController: UIViewController) -> Bool {
        // Check if ad is ready
        guard let interstitial = interstitialAd, isInterstitialReady else {
            print("⚠️ Interstitial ad not ready yet")
            // Load next ad for next time
            loadInterstitialAd()
            return false
        }
        
        // Show the ad
        print("🎬 Showing interstitial ad")
        interstitial.present(from: viewController)
        
        // Mark as not ready and load next ad
        isInterstitialReady = false
        
        return true
    }
}

// MARK: - FullScreenContentDelegate

extension AdMobManager: FullScreenContentDelegate {
    
    /// Called when the ad is dismissed
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("❌ Interstitial ad dismissed")
        // Load next ad
        loadInterstitialAd()
        
        // Notify that ad was dismissed (use after a small delay to ensure view hierarchy is restored)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("InterstitialAdDismissed"), object: nil)
        }
    }
    
    /// Called when the ad fails to present
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Interstitial ad failed to present: \(error.localizedDescription)")
        // Load next ad
        loadInterstitialAd()
    }
}
