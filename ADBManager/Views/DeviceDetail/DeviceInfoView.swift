//
//  DeviceInfoView.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI
import XPCLibrary

struct DeviceInfoView: View {
    let device: Device
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Information")
                .font(.headline)
            
            InfoRow(label: "Device ID", value: device.id)
            InfoRow(label: "Status", value: device.state.displayName.capitalized)
            
            if let model = device.model {
                InfoRow(label: "Model", value: model)
            }
            
            if let manufacturer = device.manufacturer {
                InfoRow(label: "Manufacturer", value: manufacturer)
            }
            
            if let androidVersion = device.androidVersion {
                InfoRow(label: "Android Version", value: androidVersion)
            }
            
            if let apiLevel = device.apiLevel {
                InfoRow(label: "API Level", value: apiLevel)
            }
            
            if let batteryLevel = device.batteryLevel {
                InfoRow(label: "Battery", value: batteryLevel)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    DeviceInfoView(device: Device(id: "ABC123", stateString: "device"))
        .padding()
}
