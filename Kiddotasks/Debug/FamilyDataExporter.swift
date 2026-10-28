import Foundation

/// Export current family data as JSON string
/// Use: let json = FamilyDataExporter.exportCurrentFamily()
/// Then share this JSON with the webapp migration tool
struct FamilyDataExporter {
    
    /// Exports the current family data as a JSON string
    /// Returns nil if no family data is available
    static func exportCurrentFamily() -> String? {
        guard let store = LocalFamilyDataStore.shared else {
            print("LocalFamilyDataStore not available")
            return nil
        }
        
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
    /// Returns the file URL or nil on failure
    static func exportToFile(filename: String = "family-data-\(Date()).json") -> URL? {
        guard let jsonString = exportCurrentFamily() else {
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
    static func printSummary() {
        guard let store = LocalFamilyDataStore.shared else {
            print("LocalFamilyDataStore not available")
            return
        }
        
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
