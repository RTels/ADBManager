//
//  DeviceListItem.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary

struct DeviceListItem: View {
    let device: Device
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            
            VStack(alignment: .leading, spacing: 4) {
                // Device name only
                Text(displayName)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                // Status + Battery on same line
                HStack(spacing: 4) {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.8) : statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(device.state.displayName)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    batteryIndicator
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Always reserve space for chevron, but only show when selected
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .clear)  // ← Invisible when not selected
                .frame(width: 12)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contentShape(Rectangle())
    }



    // MARK: - Battery Indicator
    
    @ViewBuilder
    private var batteryIndicator: some View {
        if let batteryString = device.batteryLevel,
           let batteryPercent = Int(batteryString.replacingOccurrences(of: "%", with: "")) {
            
            HStack(spacing: 3) {
                Image(systemName: batteryIcon(for: batteryPercent))
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                
                Text("\(batteryPercent)%")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
        }
    }
    
    private func batteryIcon(for percent: Int) -> String {
        switch percent {
        case 0..<20:
            return "battery.0"
        case 20..<50:
            return "battery.25"
        case 50..<75:
            return "battery.50"
        case 75..<95:
            return "battery.75"
        case 95...100:
            return "battery.100"
        default:
            return "battery.100"
        }
    }
    
    // MARK: - Helpers
    
    private var displayName: String {
        if let model = device.model, !model.isEmpty {
            return model
        }
        return device.id
    }
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? .white.opacity(0.2) : statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIcon)
                .foregroundColor(isSelected ? .white : statusColor)
        }
    }
    
    private var statusColor: Color {
        switch device.state {
        case .device: return .green
        case .offline: return .orange
        case .unauthorized: return .red
        case .unknown: return .gray
        }
    }
    
    private var statusIcon: String {
        switch device.state {
        case .device: return "iphone"
        case .offline: return "moon.fill"
        case .unauthorized: return "lock.fill"
        case .unknown: return "questionmark"
        }
    }
}

#Preview("With Battery - High") {
    DeviceListItem(
        device: {
            let device = Device(id: "ABC123", stateString: "device")
            device.model = "Pixel 6 Pro"
            device.batteryLevel = "85%"
            return device
        }(),
        isSelected: false
    )
    .padding()
}

#Preview("With Battery - Low") {
    DeviceListItem(
        device: {
            let device = Device(id: "ABC123", stateString: "device")
            device.model = "Pixel 6 Pro"
            device.batteryLevel = "15%"
            return device
        }(),
        isSelected: true
    )
    .padding()
}

#Preview("All Battery States") {
    ScrollView {
        LazyVStack(spacing: 4) {
            DeviceListItem(
                device: {
                    let d = Device(id: "1", stateString: "device")
                    d.model = "Critical"
                    d.batteryLevel = "5%"
                    return d
                }(),
                isSelected: false
            )
            
            DeviceListItem(
                device: {
                    let d = Device(id: "2", stateString: "device")
                    d.model = "Low"
                    d.batteryLevel = "25%"
                    return d
                }(),
                isSelected: false
            )
            
            DeviceListItem(
                device: {
                    let d = Device(id: "3", stateString: "device")
                    d.model = "Medium"
                    d.batteryLevel = "60%"
                    return d
                }(),
                isSelected: true
            )
            
            DeviceListItem(
                device: {
                    let d = Device(id: "4", stateString: "device")
                    d.model = "Full"
                    d.batteryLevel = "98%"
                    return d
                }(),
                isSelected: false
            )
        }
        .padding(8)
    }
    .frame(width: 300, height: 400)
}
