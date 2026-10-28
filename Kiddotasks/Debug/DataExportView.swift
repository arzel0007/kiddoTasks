import SwiftUI

/// Debug view to export current family data as JSON
/// Usage: Add `DataExportView()` to any SwiftUI view for debugging
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
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(10)
                    
                    Button("Copy to Clipboard") {
                        UIPasteboard.general.string = exportText
                        showingAlert = true
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .navigationTitle("Data Export")
        .alert("Copied!", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        }
        .onDisappear {
            exportText = ""
        }
    }
    
    private func exportCurrentData() {
        isExporting = true
        
        // Get the current AppState from environment
        // This works because AppState is @Observable and passed through @Environment
        if let appState = UIApplication.shared.windows.first?.rootViewController?.presentingViewController?.presentingViewController?.presentingViewController as? AppState,
           let snapshot = appState.store.currentSnapshot() {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(snapshot)
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    self.exportText = jsonString
                }
            } catch {
                print("Export failed: \(error)")
            }
        } else if let snapshot = AppState().store.currentSnapshot() {
            // Fallback: create a new AppState (for preview mode)
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(snapshot)
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    self.exportText = jsonString
                }
            } catch {
                print("Export failed: \(error)")
            }
        } else {
            print("No family data available")
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
