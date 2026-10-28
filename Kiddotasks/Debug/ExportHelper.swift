import Foundation

/// Helper for exporting family data - call from Xcode debugger or add to debug UI
struct ExportHelper {
    
    /// Call this from Xcode debugger to print current state:
    /// (lldb) po ExportHelper.printState()
    static func printState() {
        guard let appDelegate = UIApplication.shared.delegate as? KiddotasksApp else {
            print("❌ Could not access app delegate")
            return
        }
        
        // Access the AppState through the @State property
        print("📱 KiddoTasks Debug")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Note: Direct @State access from debugger requires Swift runtime
        // The recommended approach is to add a debug button in the UI
        print("💡 Add to RootView or ParentCenter for debug button:")
        print("   Button(\"Export Data\") {")
        print("       let helper = ExportHelper()")
        print("       helper.exportCurrentData()")
        print("   }")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    /// Export current family data to JSON string
    /// Note: This requires access to the actual AppState instance
    /// Usage: Add this to a button action in your SwiftUI view
    func exportCurrentData(store: LocalFamilyDataStore) -> String? {
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
    func exportToFile(store: LocalFamilyDataStore, filename: String = "family-data.json") {
        guard let jsonString = exportCurrentData(store: store) else {
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
    
    /// Copy to clipboard
    func copyToClipboard(store: LocalFamilyDataStore) {
        guard let jsonString = exportCurrentData(store: store) else {
            return
        }
        
        UIPasteboard.general.string = jsonString
        print("✅ JSON copied to clipboard! (\(jsonString.count) chars)")
    }
}
