//
//  AdMobConfig.swift
//  Football Player Trivia
//
//  Secure AdMob configuration
//  IMPORTANT: Add AdMobKeys.plist to .gitignore
//

import Foundation

struct AdMobConfig {
    static let shared = AdMobConfig()
    
    private let applicationID: String
    private let bannerAdUnitID: String
    private let interstitialAdUnitID: String
    
    private init() {
        // Load from AdMobKeys.plist (not tracked in Git)
        guard let path = Bundle.main.path(forResource: "AdMobKeys", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            fatalError("⚠️ AdMobKeys.plist not found. Create this file with your AdMob keys.")
        }
        
        guard let appID = dict["GADApplicationIdentifier"],
              let bannerID = dict["BannerAdUnitID"],
              let interstitialID = dict["InterstitialAdUnitID"] else {
            fatalError("⚠️ Required AdMob keys missing in AdMobKeys.plist")
        }
        
        self.applicationID = appID
        self.bannerAdUnitID = bannerID
        self.interstitialAdUnitID = interstitialID
    }
    
    var getApplicationID: String { applicationID }
    var getBannerAdUnitID: String { bannerAdUnitID }
    var getInterstitialAdUnitID: String { interstitialAdUnitID }
}
