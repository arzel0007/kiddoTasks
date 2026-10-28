import Foundation
import Observation

// Import the main module to access Kiddotasks types
#if canImport(Kiddotasks)
import Kiddotasks
#endif

/// Export current family data as JSON string
/// Use: let json = FamilyDataExporter.exportCurrentFamily(store: appState.store)
/// Then share this JSON with the webapp migration tool
struct FamilyDataExporter {
    
    /// Exports the current family data as a JSON string
    /// - Parameter store: The LocalFamilyDataStore instance to export from
    /// Returns nil if no family data is available
    static func exportCurrentFamily(store: LocalFamilyDataStore) -> String? {
        guard let snapshot = store.currentSnapshot() else {
            print("No family snapshot available")
            return nil
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to encode family data: \(error)")
            return nil
        }
    }
    
    /// Exports to a file in the documents directory
    /// - Parameter store: The LocalFamilyDataStore instance to export from
    /// - Parameter filename: Optional filename (defaults to family-data-{date}.json)
    /// Returns the file URL or nil on failure
    static func exportToFile(store: LocalFamilyDataStore, filename: String = "family-data-\(Date()).json") -> URL? {
        guard let jsonString = exportCurrentFamily(store: store) else {
            return nil
        }
        
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = docsDir.appendingPathComponent(filename)
        
        do {
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to write file: \(error)")
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
        print("Tasks: \(snapshot.tasks.count)")
        print("Rewards: \(snapshot.rewards.count)")
        print("Completions: \(snapshot.completions.count)")
        print("Claims: \(snapshot.claims.count)")
        print("Transactions: \(snapshot.transactions.count)")
        print("=================================")
    }
}
