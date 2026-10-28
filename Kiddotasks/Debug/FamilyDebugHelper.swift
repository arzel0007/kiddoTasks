import Foundation
import UIKit
import Observation

// Import the main module to access Kiddotasks types
#if canImport(Kiddotasks)
import Kiddotasks
#endif

/// Helper functions for debugging family data export
/// Usage: Call from Xcode debugger or add to a debug button in your app
struct FamilyDebugHelper {
    
    /// Prints a summary of current family data to the console
    /// - Parameter store: The LocalFamilyDataStore instance to export from
    static func printCurrentState(store: LocalFamilyDataStore) {
        guard let snapshot = store.currentSnapshot() else {
            print("No family snapshot available")
            return
        }
        
        print("\nFamily Data Debug Info")
        print("Family: \(snapshot.family.name)")
        print("Children: \(snapshot.children.count)")
        snapshot.children.forEach { print("  - \($0.name): \($0.activePoints) ⭐") }
        print("Tasks: \(snapshot.tasks.count)")
        print("Rewards: \(snapshot.rewards.count)")
        print("Completions: \(snapshot.completions.count)")
        print("Claims: \(snapshot.claims.count)")
        print("Transactions: \(snapshot.transactions.count)")
        print("")
    }
    
    /// Exports current family data to a JSON file in the documents directory
    /// - Parameter store: The LocalFamilyDataStore instance to export from
    /// - Returns: File URL or nil on failure
    static func exportToFile(store: LocalFamilyDataStore, filename: String = "family-data-\(Date().formatted(date: .omitted, time: .shortened)).json") -> URL? {
        guard let snapshot = store.currentSnapshot() else {
            print("No family snapshot available")
            return nil
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            
            guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                return nil
            }
            
            let fileURL = docsDir.appendingPathComponent(filename)
            try String(data: data, encoding: .utf8)?.write(to: fileURL, atomically: true, encoding: .utf8)
            
            print("Exported to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }
    
    /// Copies current family data JSON to clipboard
    /// - Parameter store: The LocalFamilyDataStore instance to export from
    /// - Returns: true if successful, false otherwise
    static func copyToClipboard(store: LocalFamilyDataStore) -> Bool {
        guard let snapshot = store.currentSnapshot() else {
            print("No family snapshot available")
            return false
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("Could not convert to string")
                return false
            }
            
            UIPasteboard.general.string = jsonString
            print("JSON copied to clipboard!")
            return true
        } catch {
            print("Export failed: \(error)")
            return false
        }
    }
}
