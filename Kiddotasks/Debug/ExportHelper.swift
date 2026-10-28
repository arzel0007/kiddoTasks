import Foundation
import UIKit
import Observation

// Import the main module to access Kiddotasks types
#if canImport(Kiddotasks)
import Kiddotasks
#endif

/// Helper for exporting family data - call from anywhere in the app
/// Usage: Add a debug button to any SwiftUI view and call ExportHelper.copyToClipboard()
struct ExportHelper {
    
    /// Copy current family data JSON to clipboard
    /// - Parameter store: The LocalFamilyDataStore instance from your app
    func copyToClipboard(store: LocalFamilyDataStore) {
        guard let snapshot = store.currentSnapshot() else {
            print("❌ No family snapshot available")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ Could not convert to string")
                return
            }
            
            UIPasteboard.general.string = jsonString
            print("✅ JSON copied to clipboard! (\(jsonString.count) chars)")
            print("📋 Paste into web migration tool at /admin/migrate-data")
        } catch {
            print("❌ Export failed: \(error)")
        }
    }
    
    /// Export current family data to JSON string
    /// - Parameter store: The LocalFamilyDataStore instance from your app
    func exportToString(store: LocalFamilyDataStore) -> String? {
        guard let snapshot = store.currentSnapshot() else {
            print("❌ No family snapshot available")
            return nil
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ Could not convert to string")
                return nil
            }
            
            print("✅ Exported \(jsonString.count) characters")
            return jsonString
        } catch {
            print("❌ Export failed: \(error)")
            return nil
        }
    }
    
    /// Export to documents directory
    /// - Parameter store: The LocalFamilyDataStore instance from your app
    /// - Parameter filename: Optional filename (defaults to family-data-{date}.json)
    func exportToFile(store: LocalFamilyDataStore, filename: String = "family-data-\(Date().formatted(date: .omitted, time: .shortened)).json") {
        guard let jsonString = exportToString(store: store) else {
            return
        }
        
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access documents directory")
            return
        }
        
        let fileURL = docsDir.appendingPathComponent(filename)
        
        do {
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Exported to: \(fileURL.path)")
        } catch {
            print("❌ Failed to write file: \(error)")
        }
    }
}
