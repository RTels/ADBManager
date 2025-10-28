//
//  DeviceHeaderView.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//


import SwiftUI
import XPCLibrary

struct DeviceHeaderView: View {
    let device: Device
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 50))
                    .foregroundColor(statusColor)
            }
            
            Text(device.displayName)
                .font(.title)
                .fontWeight(.semibold)
            
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(device.state.displayName.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
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

#Preview {
    DeviceHeaderView(device: Device(id: "ABC123", stateString: "device"))
}

