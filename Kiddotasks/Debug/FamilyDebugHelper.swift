import Foundation
import UIKit

/// Extension to get the current AppState from the app's main window
extension UIApplication {
    
    /// Attempts to find the AppState instance from the app's view controller hierarchy
    /// Note: This uses private API patterns and may need adjustment based on your app structure
    var currentAppState: AppState? {
        guard let appDelegate = shared.delegate as? KiddotasksApp else {
            print("Could not access KiddotasksApp")
            return nil
        }
        // Access the @State var directly (requires Swift runtime reflection)
        // This is a workaround - for production use, add a proper debug view
        return nil
    }
}

/// Simple helper to print family data summary from anywhere in the app
/// Usage: FamilyDebugHelper.printCurrentState()
struct FamilyDebugHelper {
    
    /// Prints a summary of current family data to the console
    static func printCurrentState() {
        guard let appDelegate = UIApplication.shared.delegate as? KiddotasksApp else {
            print("❌ Could not access app delegate")
            return
        }
        
        guard let store = appDelegate.store else {
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
        guard let appDelegate = UIApplication.shared.delegate as? KiddotasksApp else {
            print("❌ Could not access app delegate")
            return nil
        }
        
        guard let store = appDelegate.store else {
            print("❌ Could not access store")
            return nil
        }
        
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
        guard let appDelegate = UIApplication.shared.delegate as? KiddotasksApp else {
            print("❌ Could not access app delegate")
            return false
        }
        
        guard let store = appDelegate.store else {
            print("❌ Could not access store")
            return false
        }
        
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
            return true
        } catch {
            print("❌ Export failed: \(error)")
            return false
        }
    }
}
