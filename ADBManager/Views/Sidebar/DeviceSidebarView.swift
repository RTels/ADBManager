//
//  DeviceSidebarView.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary

struct DeviceSidebarView: View {
    @ObservedObject var adbService: ADBService
    @Binding var selectedDevice: Device?
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            
            if adbService.isLoading {
                ProgressView("Searching...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if adbService.devices.isEmpty {
                emptyState
            } else {
                deviceList
            }
            
            Divider()
        }
        .frame(minWidth: 250, idealWidth: 300)
    }
    
    private var sidebarHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.accentColor)
                    Text("Devices")
                        .font(.headline)
                }
                
                if adbService.isMonitoring {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("Monitoring")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(" ")
                        .font(.caption)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 66)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    
    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(adbService.devices) { device in
                    Button(action: {
                        selectedDevice = device  
                    }) {
                        DeviceListItem(
                            device: device,
                            isSelected: selectedDevice?.id == device.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No Devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    DeviceSidebarView(
        adbService: {
            let service = ADBService()
            let device1 = Device(id: "ABC123", stateString: "device")
            device1.model = "Pixel 6"
            let device2 = Device(id: "DEF456", stateString: "device")
            device2.model = "Redmi Note 14"
            service.devices = [device1, device2]
            return service
        }(),
        selectedDevice: .constant(nil)
    )
    .frame(width: 300, height: 400)
}
