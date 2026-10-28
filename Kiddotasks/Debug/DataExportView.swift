import SwiftUI

/// Debug view to export current family data as JSON
/// Usage: Add `DataExportView()` to your preview or debug navigation
struct DataExportView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var showingAlert = false
    @State private var exportText = ""
    @State private var isExporting = false
    
    var body: some View {
        List {
            Section {
                Button(action: exportCurrentData) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Family Data")
                    }
                }
                .disabled(isExporting)
                
                Button(action: clearClipboard) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Clipboard")
                    }
                    .foregroundColor(.red)
                }
            }
            
            if !exportText.isEmpty {
                Section("Exported JSON") {
                    Text(exportText)
                        .font(.monospace)
                        .lineLimit(10)
                    
                    Button("Copy to Clipboard") {
                        UIPasteboard.general.string = exportText
                        showingAlert = true
                    }
                    .buttonStyle(BorderlessButtonStyle()
                }
            }
        }
        .navigationTitle("Data Export")
        .alert("Copied!", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
        .onChange(of: presentationMode.wrappedValue) { _, _ in
            // Auto-clear when view disappears
            exportText = ""
        }
    }
    
    private func exportCurrentData() {
        isExporting = true
        
        // Access the shared store
        let store = LocalFamilyDataStore.shared
        
        if let snapshot = store.currentSnapshot() {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(snapshot)
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    self.exportText = jsonString
                }
            } catch {
                print("Export failed: \(error)")
                // Handle error
            }
        } else {
            print("No family data available")
            // Show error
        }
        
        isExporting = false
    }
    
    private func clearClipboard() {
        UIPasteboard.general.string = ""
    }
}

#Preview {
    NavigationView {
        DataExportView()
    }
}
