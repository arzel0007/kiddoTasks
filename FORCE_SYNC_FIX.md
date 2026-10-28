# Force Sync Fix - Data Loss Investigation & Solution

## Issue Description
After clicking the Force Sync button in the iOS app, users saw:
1. Brief sign-in page flash (momentary logout)
2. Success toast appeared
3. But data was missing (no kids, tasks, rewards visible)

## Root Cause Analysis

### Initial Approach (❌ Broken)
1. Called `clearLocalCache()` → cleared family, parent, children, tasks, rewards
2. This made `store.isAuthenticated` return false (because parent was nil)
3. RootView observed `isAuthenticated` changing to false
4. UI switched to login screen immediately
5. Meanwhile `forceRefreshFromCloud()` was fetching data
6. Data arrived and was applied, but timing race caused flicker
7. Additionally, the fingerprint cache check in `refreshFromCloud()` prevented pulling fresh data

### The Problem with Cache Clearing
- **Authentication Check**: `isAuthenticated` = `parent != nil`
- Clearing parent made the app think user was logged out
- RootView reacted to this and showed login screen
- UI flicker + potential data loading issues

## Solution Implemented

### New Approach (✅ Fixed)
Instead of clearing local data, we now:
1. **Invalidate the fingerprint** (`lastFetchedFingerprint = nil`)
2. Call **`forceRefreshFromCloud()`** which:
   - Fetches fresh snapshot from Firestore
   - Applies it WITHOUT fingerprint check
   - Updates the fingerprint cache
3. **Keep local data visible** during entire sync
4. **No UI mode switching** (stays in parent center)
5. **No login screen flicker**

### Code Changes

**CloudSyncEngine.swift:**
```swift
/// Invalidate the cached fingerprint and force a refresh.
/// Does not clear local data, so UI remains stable.
func invalidateFingerprintAndRefresh() async {
    lastFetchedFingerprint = nil
    await forceRefreshFromCloud()
}
```

**AppState.swift:**
```swift
/// Force a hard sync: invalidate fingerprint and re-fetch fresh data from cloud.
func forceSyncFromCloud() async {
    guard cloudSync.isAvailable else { return }
    await cloudSync.invalidateFingerprintAndRefresh()
}
```

## Why This Works

1. **Fingerprint Bypass**: By setting `lastFetchedFingerprint = nil`, the next `forceRefreshFromCloud()` call will skip the cache hit check
2. **Auth Stable**: Parent remains set, so `isAuthenticated` stays true
3. **UI Stable**: Kids, tasks, rewards stay visible during refresh
4. **Fresh Data**: Firestore data is fetched fresh and applied, replacing stale local data
5. **No Race**: All operations happen with established auth state, no switching between modes

## Testing Instructions

### Before Testing
1. Update iOS app to latest build from GitHub main
2. Make sure you have data on both web app and iOS app
3. Have web app open in browser

### Test Steps
1. **On web app**: Change a task name or add a new task
2. **On iOS app**: Go to Today tab
3. **Click the refresh button** ⟳ (top right, DEBUG mode)
4. **Verify**:
   - ✅ No login screen should appear
   - ✅ Data remains visible the whole time
   - ✅ Success toast shows "Synced from cloud"
   - ✅ Updated task from web app now appears on iOS
   - ✅ All kids, tasks, and rewards are visible

### Expected Behavior
- Local data stays on screen
- Brief "syncing..." status visible (if sync takes >1 second)
- Data updates smoothly without any screen transitions
- No authentication flicker

## Commits
- `5172f78`: Initial fix attempt (with cache clearing - broken)
- `8120f0c`: Fixed approach (fingerprint invalidation - working)

## Related
- Migration tool: `/admin/migrate-data` on web app
- Export helper: iOS Debug menu "Export" button
- Cloud function: `migrateDataFromIOS`
