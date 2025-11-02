#!/usr/bin/env python3
"""
Update Bundled Database Script
================================
This script downloads the latest 2025 NFL snap count data from nflverse
and updates the bundled football.db file that ships with the app.

Run this BEFORE submitting a new version to the App Store to ensure
new users get the most up-to-date data without needing to click "Update 2025 Data".

Usage:
    python3 update_bundled_db.py

Requirements:
    - Python 3.x
    - No external dependencies (uses only standard library)
"""

import sqlite3
import urllib.request
import os
import sys
from datetime import datetime

# Configuration
NFLVERSE_URL = "https://github.com/nflverse/nflverse-data/releases/download/snap_counts/snap_counts_2025.csv"
DB_PATH = "Football Player Trivia/football.db"

def download_csv():
    """Download the latest 2025 snap counts from nflverse"""
    print("📥 Downloading latest 2025 data from nflverse...")
    print(f"   URL: {NFLVERSE_URL}")
    
    try:
        with urllib.request.urlopen(NFLVERSE_URL) as response:
            csv_data = response.read().decode('utf-8')
        
        print(f"✅ Downloaded {len(csv_data)} bytes")
        return csv_data
    except Exception as e:
        print(f"❌ Download failed: {e}")
        sys.exit(1)

def update_database(csv_data):
    """Parse CSV and update the bundled database"""
    print(f"\n📊 Updating database at: {DB_PATH}")
    
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found at {DB_PATH}")
        print("   Make sure you're running this from the project root directory")
        sys.exit(1)
    
    # Connect to database
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Delete existing 2025 data
    print("🗑️  Deleting old 2025 data...")
    cursor.execute("DELETE FROM snap_counts WHERE season = 2025")
    print(f"   Deleted {cursor.rowcount} old records")
    
    # Parse CSV and aggregate
    print("📋 Parsing CSV data...")
    lines = csv_data.strip().split('\n')
    
    # Dictionary to aggregate snaps: {player_key: (id, name, team, pos, off, def, st)}
    player_aggregates = {}
    
    # Skip header row
    for line in lines[1:]:
        if not line.strip():
            continue
        
        columns = line.split(',')
        if len(columns) < 16:
            continue
        
        player_name = columns[5].strip()
        player_id = columns[6].strip()
        position = columns[7].strip()
        team = columns[8].strip()
        
        # Handle potential empty values
        offense_snaps = int(columns[10].strip() or 0)
        defense_snaps = int(columns[12].strip() or 0)
        st_snaps = int(columns[14].strip() or 0)
        
        # Create unique key
        key = f"{player_id}_{team}"
        
        # Aggregate snaps
        if key in player_aggregates:
            existing = player_aggregates[key]
            player_aggregates[key] = (
                existing[0],  # id
                existing[1],  # name
                existing[2],  # team
                existing[3],  # position
                existing[4] + offense_snaps,  # off
                existing[5] + defense_snaps,  # def
                existing[6] + st_snaps        # st
            )
        else:
            player_aggregates[key] = (
                player_id,
                player_name,
                team,
                position,
                offense_snaps,
                defense_snaps,
                st_snaps
            )
    
    print(f"   Aggregated {len(player_aggregates)} unique players")
    
    # Insert aggregated data
    print("💾 Inserting new 2025 data...")
    insert_query = """
        INSERT INTO snap_counts (player_id, player_name, season, team, position, offense_snaps, defense_snaps, st_snaps)
        VALUES (?, ?, 2025, ?, ?, ?, ?, ?)
    """
    
    inserted_count = 0
    for key, player in player_aggregates.items():
        cursor.execute(insert_query, player)
        inserted_count += 1
    
    conn.commit()
    conn.close()
    
    print(f"✅ Inserted {inserted_count} player records for 2025")

def main():
    """Main function"""
    print("=" * 60)
    print("  NFL 2025 Bundled Database Update Script")
    print("=" * 60)
    print(f"\nCurrent time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Target database: {DB_PATH}\n")
    
    # Step 1: Download CSV
    csv_data = download_csv()
    
    # Step 2: Update database
    update_database(csv_data)
    
    print("\n" + "=" * 60)
    print("✅ DATABASE UPDATE COMPLETE!")
    print("=" * 60)
    print("\nNext steps:")
    print("1. Test the app to verify the updated data loads correctly")
    print("2. Commit the updated football.db file to git")
    print("3. Archive and upload to App Store")
    print("\nNew users will now get fresh 2025 data on first launch!")
    print("They won't need to click 'Update 2025 Data' until after")
    print("the next week's games are played.\n")

if __name__ == "__main__":
    main()
