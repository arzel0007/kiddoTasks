# iOS Data Export Guide

## Quick Start (3 Steps)

### Step 1: Add Export Button to Your App

Open `RootView.swift` or any view where you want the export functionality:

```swift
import Kiddotasks.Debug  // Add at the top

// Add this anywhere in your view body:
#if DEBUG
Button("Export Family Data") {
    let helper = ExportHelper()
    helper.copyToClipboard(store: appState.store)
}
.font(.caption)
.opacity(0.5)
#endif
```

### Step 2: Run the App

1. Build and run the app in Xcode
2. Sign in to your family
3. Tap the "Export Family Data" button
4. The JSON will be copied to your clipboard

### Step 3: Use the Data

1. Paste the JSON from clipboard to a file or the web migration tool
2. Go to `/admin/migrate-data` in the web app
3. Paste the JSON and click "Migrate Data"

---

## Alternative: Using Xcode Debugger

If you can't modify the code:

1. **Build and run** the app in Xcode
2. **Click the Pause button** in Xcode to break execution
3. **Open the debugger console** (View > Debug Area > Activate Console)
4. **Type this command**:
```
po let helper = ExportHelper(); helper.copyToClipboard(store: AppState().store)
```

Wait, this won't work either because we need the actual app state. Let me provide a better approach:

---

## Recommended Approach: Add Debug Button

1. Open any parent view (e.g., `ParentCenterViews.swift`)
2. Add a hidden debug button:
```swift
#if DEBUG
Button("Export") {
    let helper = ExportHelper()
    helper.copyToClipboard(store: appState.store)
}
.opacity(0.1)  // Very faint, but tappable
#endif
```

3. Build and run
4. Tap the faint button to export
5. Check the Xcode console for confirmation

---

## Verifying the Export

After exporting, check the Xcode console for:
```
✅ JSON copied to clipboard! (XXXXX chars)
```

Then paste the JSON from clipboard into the web migration tool.
