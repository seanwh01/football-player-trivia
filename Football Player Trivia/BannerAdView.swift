//
//  BannerAdView.swift
//  Baseball Player Trivia
//
//  SwiftUI wrapper for Google AdMob banner ads
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    @Binding var refreshTrigger: Int // Increment to refresh ad
    
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = getRootViewController()
        banner.delegate = context.coordinator
        
        // Load ad asynchronously to avoid blocking UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            banner.load(Request())
        }
        
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // Reload ad when refresh trigger changes
        if context.coordinator.lastRefreshTrigger != refreshTrigger {
            context.coordinator.lastRefreshTrigger = refreshTrigger
            print("🔄 Refreshing banner ad (trigger: \(refreshTrigger))")
            uiView.load(Request())
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Helper to get root view controller
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        return topController
    }
    
    class Coordinator: NSObject, BannerViewDelegate {
        var lastRefreshTrigger: Int = 0
        
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ Banner ad loaded successfully")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Banner ad failed to load: \(error.localizedDescription)")
        }
        
        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("📺 Banner ad will present screen")
        }
        
        func bannerViewWillDismissScreen(_ bannerView: BannerView) {
            print("❌ Banner ad will dismiss screen")
        }
    }
}

// MARK: - Banner Ad Container

/// Container view that shows banner ad with proper sizing
struct BannerAdContainer: View {
    let adUnitID: String
    @Binding var refreshTrigger: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Banner ad (320x50 standard size)
            BannerAdView(adUnitID: adUnitID, refreshTrigger: $refreshTrigger)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        }
    }
}
