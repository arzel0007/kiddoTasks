# Data Sync - Complete Summary

## ✅ What Has Been Fixed

### 1. Type Alignment
Updated `apps/web/src/lib/types.ts` to match iOS Swift models:
- KiddoTask: Made `recurrence` required
- Child: Added `version` field
- TaskCompletion: Added `approvedBy`, `pointTransactionId`
- RewardClaim: Added `REDEEMED` status, `approvedBy`
- PointTransaction: Added `relatedId`, `createdBy`, `isReversed`, `reversalTransactionId`

### 2. Migration Tool Created
- **URL**: `/admin/migrate-data` (admin page)
- **Purpose**: Merge iOS app data into webapp while preserving webapp points
- **Features**: Parse JSON preview, migration execution, status display

### 3. iOS Export Tools
- **FamilyDataExporter**: Export current family data as JSON
- **DataExportView**: SwiftUI preview view for exporting data

## 📋 How to Sync Data

### Step 1: Export from iOS App

**Option A: Using FamilyDataExporter (recommended)**

Add this code to your iOS app's debug view or use lldb:

```swift
import FamilyDataExporter

// Print summary to console
FamilyDataExporter.printSummary()

// Get JSON string
if let json = FamilyDataExporter.exportCurrentFamily() {
    print(json)
}
```

**Option B: Using DataExportView**

1. Navigate to the DataExportView in your iOS app
2. Tap "Export Family Data"
3. The JSON will be copied to clipboard automatically
4. Paste it somewhere safe

### Step 2: Import to Webapp

1. Go to `/admin/migrate-data` in the webapp
2. Paste the iOS JSON data
3. Click "Parse JSON" to preview
4. Click "Migrate Data" to execute

### Step 3: Verify

1. **Webapp**: Refresh the page
2. **iOS**: Force close and reopen the app
3. Check that:
   - Points match webapp values
   - Tasks show iOS icons/descriptions
   - Children have iOS avatars
   - All data appears correct

## 🎯 Data Strategy

| Data Type | Source | Action |
|-----------|--------|--------|
| Points | Webapp | Preserved |
| Tasks | iOS | Overwritten |
| Children Icons | iOS | Overwritten |
| Completions | Webapp | Preserved |
| Claims | Webapp | Preserved |
| Rewards | iOS | Overwritten |

## 🔄 Current Status

### ✅ Committed
- 3 commits ahead of origin/main
- All changes committed locally
- Build successful

### ⚠️ Manual Steps Required

Due to network permissions, you'll need to manually:

1. **Push to GitHub** (run in your terminal):
```bash
cd /Users/arjayresurreccion/projects/GitHub/kiddoTasks
git push origin main
```

2. **Deploy Firebase** (run in your terminal):
```bash
cd /Users/arjayresurreccion/projects/GitHub/kiddoTasks
firebase deploy --only hosting
```

If you get the `.config` permission error, try:
```bash
# Unlock your .config folder
sudo chown -R $USER:$(id -gn $USER) /Users/arjayresurreccion/.config
```

Then deploy:
```bash
firebase deploy --only hosting
```

## 📄 Files Created

### Webapp
- `apps/web/src/app/admin/migrate-data/page.tsx` - Migration UI
- `apps/web/MIGRATION_PLAN.md` - Detailed migration guide

### iOS
- `Kiddotasks/Debug/FamilyDataExporter.swift` - Export utility
- `Kiddotasks/Debug/DataExportView.swift` - SwiftUI preview view

### Documentation
- `SYNC_SUMMARY.md` - This file

## 🐛 Troubleshooting

### If migration fails:

1. Check Firebase is configured
2. Ensure user is signed in
3. Verify JSON format is correct
4. Check console for detailed error

### If data doesn't sync after migration:

1. Force close and reopen both apps
2. Clear app cache if needed
3. Check Firestore console for data
4. Wait 5-10 minutes for cloud sync

## 🔧 Technical Details

### Migration Script Logic

The migration tool:
1. Parses the iOS JSON data
2. Gets current familyId from Firebase Auth
3. Updates tasks from iOS (preserves recurrence config)
4. Updates rewards from iOS (preserves latest state)
5. Updates children avatars (keeps webapp points)
6. Updates task recurrence.weekdays for weekdays tasks

### Firebase Collections Affected

- `tasks/` - Replaced with iOS version
- `rewards/` - Replaced with iOS version
- `children/` - Updated icons only, points preserved
- `taskCompletions/` - Not touched (webapp authoritative)
- `rewardClaims/` - Not touched (webapp authoritative)

## 📞 Support

For issues or questions, refer to:
- `apps/web/MIGRATION_PLAN.md` - Detailed technical plan
- This file - Quick reference guide
