//
//  DeviceInfoPopover.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary

struct DeviceInfoPopover: View {
    let device: Device
    @Environment(\.dismiss) var dismiss
    @State private var showCopiedConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.headline)
                    
                    Text(device.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Info content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "Device ID", value: device.id)
                    
                    if let model = device.model {
                        InfoRow(label: "Model", value: model)
                    }
                    
                    if let manufacturer = device.manufacturer {
                        InfoRow(label: "Manufacturer", value: manufacturer)
                    }
                    
                    if let androidVersion = device.androidVersion {
                        InfoRow(label: "Android", value: androidVersion)
                    }
                    
                    if let apiLevel = device.apiLevel {
                        InfoRow(label: "API Level", value: apiLevel)
                    }
                    
                    if let batteryLevel = device.batteryLevel {
                        InfoRow(label: "Battery", value: batteryLevel)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer with copy button
            HStack {
                if showCopiedConfirmation {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Copied!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: copyAllInfo) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy All")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 350, height: 300)
    }
    
    private func copyAllInfo() {
        var info = """
        Device Information
        ==================
        
        Device ID: \(device.id)
        Status: \(device.state.displayName)
        """
        
        if let model = device.model {
            info += "\nModel: \(model)"
        }
        
        if let manufacturer = device.manufacturer {
            info += "\nManufacturer: \(manufacturer)"
        }
        
        if let androidVersion = device.androidVersion {
            info += "\nAndroid Version: \(androidVersion)"
        }
        
        if let apiLevel = device.apiLevel {
            info += "\nAPI Level: \(apiLevel)"
        }
        
        if let batteryLevel = device.batteryLevel {
            info += "\nBattery: \(batteryLevel)"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
        
        showCopiedConfirmation = true
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            showCopiedConfirmation = false
        }
    }
}

#Preview {
    DeviceInfoPopover(device: {
        let device = Device(id: "ABC123XYZ", stateString: "device")
        device.model = "Pixel 6 Pro"
        device.manufacturer = "Google"
        device.androidVersion = "14"
        device.apiLevel = "34"
        device.batteryLevel = "85%"
        return device
    }())
}
