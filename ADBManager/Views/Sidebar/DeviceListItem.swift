//
//  DeviceListItem.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI
import XPCLibrary

struct DeviceListItem: View {
    let device: Device
    
    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(device.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var displayName: String {
        if let model = device.model, !model.isEmpty {
            return model
        }
        return device.id
    }
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
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

#Preview {
    DeviceListItem(device: Device(id: "ABC123", stateString: "device"))
        .padding()
}

