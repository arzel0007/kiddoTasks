import Foundation
import UIKit

/// Helper functions for debugging family data export
/// Usage: Call from Xcode debugger or add to a debug button in your app
struct FamilyDebugHelper {
    
    /// Prints a summary of current family data to the console
    static func printCurrentState() {
        // Access the shared AppState from the main scene
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("❌ Could not access scene")
            return
        }
        
        guard let rootVC = scene.windows.first?.rootViewController else {
            print("❌ Could not access root view controller")
            return
        }
        
        // Walk the view controller hierarchy to find the app state
        // The AppState is typically passed as an environment object
        var foundAppState: AppState?
        
        func findAppState(in vc: UIViewController) {
            // Check if this view controller has AppState as an environment object
            // We'll use key-value coding to check for the presence of an AppState
            if let state = vc.value(forKey: "_environmentValues") as? [String: Any],
               let appState = state.values.first as? AppState {
                foundAppState = appState
            }
            
            // Check child view controllers
            for child in vc.children {
                findAppState(in: child)
            }
        }
        
        findAppState(in: rootVC)
        
        guard let appState = foundAppState ?? AppState() else {
            print("❌ Could not access AppState")
            return
        }
        
        guard let store = appState.store else {
            print("❌ Could not access store")
            return
        }
        
        guard let family = store.family else {
            print("❌ No family data loaded")
            return
        }
        
        print("\n✅ Family Data Debug Info")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Family: \(family.name)")
        print("Children: \(store.children.count)")
        
        store.children.forEach { child in
            print("  • \(child.name): \(child.activePoints) ⭐")
        }
        
        print("Tasks: \(store.tasks.count)")
        store.tasks.forEach { task in
            print("  • \(task.name)")
        }
        
        print("Rewards: \(store.rewards.count)")
        store.rewards.forEach { reward in
            print("  • \(reward.name) (\(reward.pointCost)⭐)")
        }
        
        print("Completions: \(store.completions.count)")
        print("Claims: \(store.claims.count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    /// Exports current family data to a JSON file in the documents directory
    /// - Returns: File URL or nil on failure
    static func exportToDocument() -> URL? {
        // Create a temporary AppState to access the store
        // Note: This creates a new instance, so use with caution
        let appState = AppState()
        let store = appState.store
        
        guard let snapshot = store.currentSnapshot() else {
            print("❌ No family snapshot available")
            return nil
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            
            guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("❌ Could not access documents directory")
                return nil
            }
            
            let filename = "family-data-\(Date().formatted(date: .omitted, time: .shortened)).json"
                .replacingOccurrences(of: ":", with: "-")
            let fileURL = docsDir.appendingPathComponent(filename)
            
            try String(data: data, encoding: .utf8)?.write(to: fileURL, atomically: true, encoding: .utf8)
            
            print("✅ Exported to: \(fileURL.path)")
            print("   File: \(filename)")
            return fileURL
        } catch {
            print("❌ Export failed: \(error)")
            return nil
        }
    }
    
    /// Copies current family data JSON to clipboard
    /// - Returns: true if successful, false otherwise
    static func copyToClipboard() -> Bool {
        // Create a temporary AppState to access the store
        let appState = AppState()
        let store = appState.store
        
        guard let snapshot = store.currentSnapshot() else {
            print("❌ No family snapshot available")
            return false
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ Could not convert to string")
                return false
            }
            
            UIPasteboard.general.string = jsonString
            print("✅ JSON copied to clipboard!")
            print("   Length: \(jsonString.count) characters")
            return true
        } catch {
            print("❌ Export failed: \(error)")
            return false
        }
    }
}
