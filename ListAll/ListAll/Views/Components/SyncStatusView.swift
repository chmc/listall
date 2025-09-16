import SwiftUI

struct SyncStatusView: View {
    @ObservedObject var cloudKitService: CloudKitService
    
    var body: some View {
        HStack(spacing: 8) {
            syncStatusIcon
            syncStatusText
            if cloudKitService.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(syncStatusBackground)
        .cornerRadius(8)
    }
    
    private var syncStatusIcon: some View {
        Group {
            switch cloudKitService.syncStatus {
            case .available:
                Image(systemName: "icloud.fill")
                    .foregroundColor(.blue)
            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(cloudKitService.isSyncing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: cloudKitService.isSyncing)
            case .offline:
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .noAccount:
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundColor(.orange)
            case .restricted:
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
            case .temporarilyUnavailable:
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
            default:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var syncStatusText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(syncStatusTitle)
                .font(.caption)
                .fontWeight(.medium)
            
            if let lastSync = cloudKitService.lastSyncDate {
                Text("Last sync: \(lastSync, formatter: timeFormatter)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let error = cloudKitService.syncError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
    }
    
    private var syncStatusBackground: Color {
        switch cloudKitService.syncStatus {
        case .available:
            return Color.blue.opacity(0.1)
        case .syncing:
            return Color.blue.opacity(0.1)
        case .offline:
            return Color.orange.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .noAccount, .restricted, .temporarilyUnavailable:
            return Color.orange.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
    
    private var syncStatusTitle: String {
        switch cloudKitService.syncStatus {
        case .available:
            return "Synced"
        case .syncing:
            return "Syncing..."
        case .offline:
            return "Offline"
        case .error:
            return "Sync Error"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "iCloud Restricted"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        case .couldNotDetermine:
            return "Unknown Status"
        case .unknown:
            return "Checking..."
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

struct SyncProgressView: View {
    @ObservedObject var cloudKitService: CloudKitService
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Syncing...")
                    .font(.headline)
                Spacer()
                Text("\(Int(cloudKitService.syncProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: cloudKitService.syncProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            if cloudKitService.pendingOperations > 0 {
                Text("\(cloudKitService.pendingOperations) operations pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        SyncStatusView(cloudKitService: CloudKitService())
        SyncProgressView(cloudKitService: CloudKitService())
    }
    .padding()
}
