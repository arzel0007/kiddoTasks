# iOS Data Export Guide

## Quick Start (2 Steps)

### Step 1: Add Export Button to a View

Open any SwiftUI view file (e.g., `RootView.swift`, `TodayDashboardView.swift`, or any parent view):

```swift
// Add to the top of the file
import Kiddotasks.Debug  // Or just import the module

// Add this button somewhere in your view body (I recommend near a settings button):
Button("Export Data") {
    let helper = ExportHelper()
    // Access appState.store - depends on how your view is structured
    // For views with @Environment(AppState.self):
    helper.copyToClipboard(store: appState.store)
}
.font(.caption)
.foregroundStyle(.secondary)
```

**If your view doesn't have access to `appState`**, add this at the top:
```swift
@Environment(AppState.self) private var appState
```

### Step 2: Run, Tap, and Use

1. **Build and run** the app in Xcode (Cmd+R)
2. **Sign in** to your family account
3. **Tap the "Export Data" button** you just added
4. Check Xcode console for confirmation:
   ```
   ✅ JSON copied to clipboard! (XXXXX chars)
   ```
5. **Go to web migration tool**: `/admin/migrate-data`
6. **Paste the JSON** and click "Migrate Data"

---

## Where to Add the Button

### Option A: RootView (Easiest)

In `RootView.swift`, add to the navigation title:

```swift
.navigationTitle("Parent Center")
.navigationBarItems(trailing: 
    #if DEBUG
    Button("Export") {
        let helper = ExportHelper()
        helper.copyToClipboard(store: appState.store)
    }
    .opacity(0.3)
    #endif
)
```

### Option B: TodayDashboardView

In `TodayDashboardView.swift`, add to the parent menu:

```swift
Section("Debug") {
    Button("Export Data") {
        let helper = ExportHelper()
        helper.copyToClipboard(store: appState.store)
    }
}
.opacity(0.2)
```

### Option C: Family Settings View

In the family settings view, add at the bottom:

```swift
Button("Export Family Data") {
    let helper = ExportHelper()
    helper.copyToClipboard(store: appState.store)
}
.font(.caption)
.opacity(0.3)
```

---

## What Gets Exported

The export includes:
- **Family** info (name, ID, settings)
- **Children** list (names, avatars, points)
- **Tasks** list (names, icons, descriptions, recurrence)
- **Rewards** list (names, icons, point costs)
- **Completions** (all task completions)
- **Claims** (reward claims)
- **Transactions** (point history)
- **Achievements** (unlock history)
- **WishlistItems** (gift wishes)

---

## Troubleshooting

### "No family snapshot available"
- You need to sign in first
- Make sure the family data is loaded
- Wait 2-3 seconds after signing in

### "Could not convert to string"
- This is a rare encoding error
- Try exporting to file instead: `helper.exportToFile(store: appState.store)`

### Button doesn't work
- Make sure you're importing the debug module correctly
- Check that `appState` is available in your view
- Verify you're signed in with a valid family

---

## Alternative: Export to File

If clipboard doesn't work, export to file instead:

```swift
Button("Export to File") {
    let helper = ExportHelper()
    helper.exportToFile(store: appState.store)
}
```

Then retrieve the file from:
```
Settings → Your App → File Sharing
```

Or use Xcode's Device Manager to download the app's container.
