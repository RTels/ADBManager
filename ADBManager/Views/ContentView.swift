//
//  ContentView.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary

struct ContentView: View {
    @StateObject private var adbService = ADBService()
    @State private var selectedDevice: Device?
    
    var body: some View {
        NavigationSplitView {
            DeviceSidebarView(
                adbService: adbService,
                selectedDevice: $selectedDevice
            )
            .frame(minWidth: 250)
        } detail: {
            DeviceDetailView(
                adbService: adbService,
                deviceId: selectedDevice?.id
            )
            .frame(minWidth: 400)
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(300)
        .onAppear {
            Task {
                await adbService.refreshDevices()
                adbService.startMonitoring()
            }
        }
    }
}

#Preview {
    ContentView()
}
