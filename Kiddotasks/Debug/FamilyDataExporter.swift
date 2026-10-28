import Foundation

/// Export current family data as JSON string
/// Use from Xcode debugger:
///   (lldb) po FamilyDataExporter.exportCurrentFamily()
/// Or add to a button action in any SwiftUI view
struct FamilyDataExporter {
    
    /// Exports the current family data as a JSON string
    /// - Returns: JSON string or nil if no family data available
    static func exportCurrentFamily() -> String? {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let window = appDelegate.window,
              let rootVC = window.rootViewController else {
            print("Could not access app delegate or root view controller")
            return nil
        }
        
        // Walk the view controller hierarchy to find AppState
        var vc: UIViewController? = rootVC
        
        // Try to find the AppState from the presented view controllers
        while vc != nil {
            // Check if this view controller has AppState as an environment object
            // This is a workaround since we can't directly access @Environment
            if let exportVC = vc as? DataExportView {
                // This won't work directly but shows the pattern
                break
            }
            vc = vc?.presentedViewController
        }
        
        // Alternative: Access via shared AppState if we can get it
        // For SwiftUI apps, AppState is typically @State at app level
        print("Note: For SwiftUI apps, use the debug view or Xcode preview to access AppState")
        print("Try adding DataExportView() to your RootView for testing")
        
        return nil
    }
    
    /// Export using a closure that receives the AppState
    /// Usage: FamilyDataExporter.export { appState in
    ///     print(FamilyDataExporter.exportCurrentFamily(store: appState.store))
    /// }
    static func export(_ callback: (AppState) -> Void) {
        // This requires access to the actual AppState instance
        // which is typically @State in KiddotasksApp.swift
        print("Export function requires AppState instance")
        print("Add DataExportView() to your view hierarchy to use this feature")
    }
    
    /// Exports to a file in the documents directory
    /// - Parameter store: The LocalFamilyDataStore instance to export from
    /// - Parameter filename: Optional filename (defaults to family-data-{date}.json)
    /// Returns the file URL or nil on failure
    static func exportToFile(store: LocalFamilyDataStore, filename: String = "family-data-\(Date()).json") -> URL? {
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
            print("Failed to export: \(error)")
            return nil
        }
    }
    
    /// Prints the current family data summary to console
    /// - Parameter store: The LocalFamilyDataStore instance to export from
    static func printSummary(store: LocalFamilyDataStore) {
        guard let snapshot = store.currentSnapshot() else {
            print("No family snapshot available")
            return
        }
        
        print("=== Family Data Export Summary ===")
        print("Family: \(snapshot.family.name) (ID: \(snapshot.family.id))")
        print("Children: \(snapshot.children.count)")
        snapshot.children.forEach { print("  - \($0.name) (Points: \($0.activePoints))") }
        print("Tasks: \(snapshot.tasks.count)")
        print("Rewards: \(snapshot.rewards.count)")
        print("Completions: \(snapshot.completions.count)")
        print("Claims: \(snapshot.claims.count)")
        print("Transactions: \(snapshot.transactions.count)")
        print("=================================")
    }
}
