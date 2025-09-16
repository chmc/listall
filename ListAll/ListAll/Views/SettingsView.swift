import SwiftUI

struct SettingsView: View {
    @State private var showCrossedOutItems = true
    @State private var enableCloudSync = true
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    
    var body: some View {
        NavigationView {
            SwiftUI.List {
                Section("Display") {
                    Toggle("Show Crossed Out Items", isOn: $showCrossedOutItems)
                }
                
                Section("Sync") {
                    Toggle("iCloud Sync", isOn: $enableCloudSync)
                }
                
                Section("Data") {
                    Button("Export Data") {
                        showingExportSheet = true
                    }
                    
                    Button("Import Data") {
                        showingImportSheet = true
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView()
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportView()
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExportViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.isExporting {
                    ProgressView("Exporting...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    VStack(spacing: 16) {
                        Button("Export to JSON") {
                            viewModel.exportToJSON()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Export to CSV") {
                            viewModel.exportToCSV()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import functionality will be implemented in a future phase")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
