# AdMob Setup Instructions

## ⚠️ IMPORTANT: Secure Your AdMob Keys

Your AdMob keys should NEVER be committed to Git. Follow these steps to set them up securely.

## Setup Steps

### 1. Get Your NEW AdMob Keys
Since your old keys were exposed on GitHub, you MUST rotate them:

1. Go to [Google AdMob Console](https://apps.admob.com/)
2. **Revoke/regenerate your exposed keys immediately**
3. Get your new keys:
   - **App ID**: Found in App settings (looks like `ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX`)
   - **Banner Ad Unit ID**: Found in Ad units
   - **Interstitial Ad Unit ID**: Found in Ad units

### 2. Update Info.plist
Open `Football Player Trivia/Info.plist` and replace the placeholder:

```xml
<key>GADApplicationIdentifier</key>
<string>REPLACE_WITH_YOUR_ADMOB_APP_ID</string>
```

With your NEW App ID:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
```

### 3. Update AdMobKeys.plist
The file `Football Player Trivia/AdMobKeys.plist` contains your ad unit IDs. Update it with your NEW keys:

```xml
<key>GADApplicationIdentifier</key>
<string>YOUR_NEW_ADMOB_APP_ID</string>
<key>BannerAdUnitID</key>
<string>YOUR_NEW_BANNER_AD_UNIT_ID</string>
<key>InterstitialAdUnitID</key>
<string>YOUR_NEW_INTERSTITIAL_AD_UNIT_ID</string>
```

### 4. Verify .gitignore
Make sure `AdMobKeys.plist` is listed in `.gitignore` so it's never committed:

```
Football Player Trivia/AdMobKeys.plist
```

## Important Notes

- ✅ `AdMobKeys.plist` is **gitignored** and safe
- ⚠️ `Info.plist` **IS tracked** by Git - do not commit real keys here if possible
- 🔒 For production, consider using Xcode build configurations or environment variables

## Security Checklist

- [ ] Revoked old exposed AdMob keys in Google Console
- [ ] Generated new AdMob keys
- [ ] Updated `Info.plist` with new App ID
- [ ] Updated `AdMobKeys.plist` with new ad unit IDs
- [ ] Verified `AdMobKeys.plist` is in `.gitignore`
- [ ] Cleaned Git history (see below)

## Cleaning Git History

Your old keys are in Git history. To remove them:

```bash
# Use BFG Repo-Cleaner or git filter-repo
# This is advanced - consider creating a fresh repo if unsure
```

## Questions?
- AdMob Console: https://apps.admob.com/
- AdMob Help: https://support.google.com/admob/
