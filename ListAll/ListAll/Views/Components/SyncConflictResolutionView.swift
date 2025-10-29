import SwiftUI
import CoreData

struct SyncConflictResolutionView: View {
    let conflictObject: NSManagedObject
    let onResolve: (CloudKitService.ConflictResolutionStrategy) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView
                conflictDetailsView
                resolutionOptionsView
                Spacer()
            }
            .padding()
            .navigationTitle("Sync Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Sync Conflict Detected")
                .font(.headline)
            
            Text("This item has been modified on multiple devices. Choose how to resolve the conflict.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var conflictDetailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conflict Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Entity:")
                        .fontWeight(.medium)
                    Text(conflictObject.entity.name ?? "Unknown")
                        .foregroundColor(.secondary)
                }
                
                if let id = conflictObject.value(forKey: "id") as? UUID {
                    HStack {
                        Text("ID:")
                            .fontWeight(.medium)
                        Text(id.uuidString.prefix(8) + "...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                if let modifiedAt = conflictObject.value(forKey: "modifiedAt") as? Date {
                    HStack {
                        Text("Last Modified:")
                            .fontWeight(.medium)
                        Text(modifiedAt, formatter: dateFormatter)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var resolutionOptionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resolution Options")
                .font(.headline)
            
            VStack(spacing: 12) {
                resolutionOption(
                    title: "Use Latest Version",
                    description: "Keep the version with the most recent modification date",
                    icon: "clock.fill",
                    color: .blue
                ) {
                    onResolve(.lastWriteWins)
                    dismiss()
                }
                
                resolutionOption(
                    title: "Use Server Version",
                    description: "Keep the version from iCloud",
                    icon: "icloud.fill",
                    color: .green
                ) {
                    onResolve(.serverWins)
                    dismiss()
                }
                
                resolutionOption(
                    title: "Use Local Version",
                    description: "Keep the version on this device",
                    icon: "iphone.fill",
                    color: .orange
                ) {
                    onResolve(.clientWins)
                    dismiss()
                }
            }
        }
    }
    
    private func resolutionOption(
        title: String,
        description: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

class SyncConflictManager: ObservableObject {
    @Published var conflicts: [NSManagedObject] = []
    @Published var showingConflictResolution = false
    @Published var currentConflict: NSManagedObject?
    
    private let cloudKitService: CloudKitService
    
    init(cloudKitService: CloudKitService) {
        self.cloudKitService = cloudKitService
    }
    
    func checkForConflicts() async {
        // Check for objects with conflicts
        let context = CoreDataManager.shared.viewContext
        let entities = ["ListEntity", "ItemEntity", "ItemImageEntity", "UserDataEntity"]
        
        // Fetch object IDs (which are Sendable) instead of managed objects
        let conflictObjectIDs: [NSManagedObjectID] = await context.perform {
            var objectIDs: [NSManagedObjectID] = []
            
            for entityName in entities {
                let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                request.predicate = NSPredicate(format: "ckServerChangeToken != nil")
                
                do {
                    let objects = try context.fetch(request)
                    objectIDs.append(contentsOf: objects.map { $0.objectID })
                } catch {
                    print("Failed to check for conflicts in \(entityName): \(error)")
                }
            }
            
            return objectIDs
        }
        
        // Fetch actual objects on main thread using the IDs
        let foundConflicts: [NSManagedObject] = conflictObjectIDs.compactMap { objectID in
            try? context.existingObject(with: objectID)
        }
        
        self.conflicts = foundConflicts
        if !foundConflicts.isEmpty {
            self.currentConflict = foundConflicts.first
            self.showingConflictResolution = true
        }
    }
    
    func resolveConflict(with strategy: CloudKitService.ConflictResolutionStrategy) async {
        guard let conflict = currentConflict else { return }
        
        await cloudKitService.resolveConflictWithStrategy(strategy, for: conflict)
        
        if let index = conflicts.firstIndex(of: conflict) {
            conflicts.remove(at: index)
        }
        
        if conflicts.isEmpty {
            showingConflictResolution = false
            currentConflict = nil
        } else {
            currentConflict = conflicts.first
        }
    }
}

#Preview {
    SyncConflictResolutionView(
        conflictObject: NSManagedObject(),
        onResolve: { _ in }
    )
}
