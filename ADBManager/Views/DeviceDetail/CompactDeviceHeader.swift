import SwiftUI
import XPCLibrary

struct CompactDeviceHeader: View {
    let device: Device
    @Binding var showDetails: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            // Device name
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.headline)
                
                Text(device.state.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Expandable details toggle
            Button(action: {
                withAnimation {
                    showDetails.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Text("Details")
                        .font(.caption)
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var statusColor: Color {
        switch device.state {
        case .device: return .green
        case .offline: return .orange
        case .unauthorized: return .red
        case .unknown: return .gray
        }
    }
}



#Preview("Offline") {
    CompactDeviceHeader(
        device: Device(id: "DEF456", stateString: "offline"),
        showDetails: .constant(false)
    )
    .frame(width: 500)
}
