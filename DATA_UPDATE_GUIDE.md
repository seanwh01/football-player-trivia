# Data Update Guide

## Overview

Your app uses NFL snap count data from the [nflverse project](https://github.com/nflverse/nflverse-data). This data is updated weekly during the NFL season.

## Two Types of Data Updates

### 1. **Bundled Database Update** (Before App Store Submission)
**Purpose:** Ensure new users get fresh data on first install  
**When:** Before each App Store version upload  
**Who:** You (developer)  

### 2. **In-App Update** (By Users After Download)
**Purpose:** Let existing users refresh data after new games  
**When:** After each week's NFL games complete  
**Who:** App users (via "Update 2025 Data" button)

---

## How to Update Bundled Database (Pre-Submission)

### Why This Matters

When you submit a new version to the App Store, the `football.db` file bundled with the app is what new users will get on first launch. If this data is outdated, they'll see old snap counts until they manually click "Update 2025 Data".

**By updating the bundled database before submission:**
- ✅ New users get fresh data immediately
- ✅ Better first-time user experience
- ✅ Users only need to click "Update 2025 Data" after new games

### Update Process

**1. Run the update script:**
```bash
cd "/Users/seanwhite/CascadeProjects/Football Player Trivia"
python3 update_bundled_db.py
```

**2. The script will:**
- Download latest 2025 snap counts from nflverse
- Delete old 2025 data from `football.db`
- Insert fresh aggregated player data
- Display success message with record counts

**3. Test the updated data:**
- Run your app in Xcode
- Play a few questions to verify data is current
- Check that player names and teams are correct

**4. Commit the updated database:**
```bash
git add "Football Player Trivia/football.db"
git commit -m "Update bundled database with latest 2025 snap counts"
git push origin main
```

**5. Archive and upload to App Store**
- Clean build folder (⌘⇧K)
- Archive your app (Product → Archive)
- Upload to App Store Connect

---

## Regular Update Schedule

### During NFL Season (September - February)

**Weekly Workflow:**

1. **Monday or Tuesday** (after games complete):
   - nflverse updates their data
   - Run `update_bundled_db.py`

2. **Before your next App Store version:**
   - Ensure you've run the script recently
   - Commit updated `football.db`
   - Submit to App Store

3. **Notify users** (optional):
   - Use in-app message or update notes
   - Tell users fresh data is available
   - Remind them about "Update 2025 Data" button

### Off-Season (March - August)

- No need to update weekly
- Data is stable between seasons
- Update before starting new season

---

## How In-App Updates Work

When users click "Update 2025 Data":

1. App downloads latest CSV from nflverse
2. Updates the *Documents directory* copy of database
3. New data available immediately
4. Last download date is saved and displayed

**Key difference:**
- Bundled database = Read-only, ships with app
- Documents database = User's personal copy, can be updated

---

## Data Source

**Source:** [nflverse/nflverse-data](https://github.com/nflverse/nflverse-data)  
**URL:** `https://github.com/nflverse/nflverse-data/releases/download/snap_counts/snap_counts_2025.csv`  
**License:** MIT License  
**Update Frequency:** Weekly during NFL season

**What's included:**
- Player names and IDs (Pro Football Reference)
- Team abbreviations
- Positions
- Offense, Defense, and Special Teams snap counts (aggregated from per-game data)

---

## Troubleshooting

### Script fails with "Database not found"
- Make sure you're in the project root directory
- Check that `Football Player Trivia/football.db` exists

### Script fails with "Download failed"
- Check internet connection
- Verify nflverse URL is still valid
- Try again later (server may be temporarily down)

### App shows old data after update
- Make sure you committed the updated `football.db`
- Clean build folder in Xcode
- Delete app from simulator/device and reinstall

### Users report wrong snap counts
- Verify when nflverse last updated their data
- Run update script again
- May take a day or two for nflverse to process new games

---

## Best Practices

1. **Update before each submission** to App Store
2. **Test after updating** to verify data integrity
3. **Document update date** in commit messages
4. **Keep script in sync** with DataUpdateService.swift logic
5. **Monitor nflverse** for any API/format changes

---

## Questions?

- Check [nflverse documentation](https://github.com/nflverse/nflverse-data)
- Review `DataUpdateService.swift` for in-app update logic
- File an issue on your GitHub repo if script has problems
