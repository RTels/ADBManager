//
//  ADBService.swift
//  ADBManager
//

import Foundation
import XPCLibrary

@MainActor
class ADBService: ObservableObject {
    
    
    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isMonitoring = false
    @Published var isSyncing = false
    @Published var syncProgress: String?
    
    
    @Published var syncCurrentCount: Int = 0
    @Published var syncTotalCount: Int = 0
    @Published var syncCurrentPhoto: String = ""
    
    @Published var needsReconnection = false
    @Published var isReconnecting = false
    @Published var deviceReconnected = false
    @Published var deviceConfirmedGone = false
    @Published var partialSyncCount: Int?
    @Published var disconnectedDeviceId: String?
    
    
    private let client: ADBServiceClient
    private var pollingTask: Task<Void, Never>?
    private var syncProgressTask: Task<Void, Never>?
    private var syncProgressCurrent = 0
    
    init(client: ADBServiceClient = ADBServiceClient()) {
        self.client = client
    }
    
    
    func startMonitoring() {
        isMonitoring = true
        client.startMonitoring()
        
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshDevices(showLoading: false)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    func stopMonitoring() {
        pollingTask?.cancel()
        isMonitoring = false
        client.stopMonitoring()
    }
    
    
    func refreshDevices(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        
        do {
            let fetchedDevices = try await client.listDevices()
            self.devices = fetchedDevices
            
            if isReconnecting, let deviceId = disconnectedDeviceId {
                let deviceExists = fetchedDevices.contains(where: { $0.id == deviceId && $0.state == DeviceState.device })
                
                if !deviceExists {
                    deviceConfirmedGone = true
                } else if deviceConfirmedGone && deviceExists {
                    deviceReconnected = true
                }
            }
            for device in fetchedDevices where device.state == .device {
                Task {
                    await fetchDeviceDetails(for: device)
                }
            }
            
        } catch {
            if !needsReconnection {
                self.error = error.localizedDescription
            }
        }
        
        if showLoading {
            isLoading = false
        }
    }
    
    func fetchDeviceDetails(for device: Device) async {
        do {
            let detailedDevice = try await client.getDeviceDetails(deviceId: device.id)
            
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = detailedDevice
            }
        } catch {
            print("Failed to fetch details for \(device.id): \(error)")
        }
    }
    
    func listFolderContents(for device: Device, at path: String) async throws -> [FolderItem] {
        return try await client.listFolderContents(deviceId: device.id, path: path)
    }

    

    
    func resumeSync(
        for device: Device,
        from sourcePath: String,
        to destinationPath: String
    ) async -> Int? {
        needsReconnection = false
        isReconnecting = false
        deviceReconnected = false
        deviceConfirmedGone = false
        disconnectedDeviceId = nil
        
        return await syncPhotos(for: device, from: sourcePath, to: destinationPath)
    }
    
    
    func syncPhotos(
            for device: Device,
            from sourcePath: String,
            to destinationPath: String
        ) async -> Int? {
            syncProgress = nil
            syncCurrentCount = 0
            syncTotalCount = 0
            syncCurrentPhoto = ""
            syncProgressCurrent = 0
            isSyncing = true
            syncProgress = "Starting sync..."
            error = nil
            
            stopMonitoring()
            startSyncProgressPolling()
            
            do {
                let count = try await client.startPhotoSync(
                    deviceId: device.id,
                    sourcePath: sourcePath,
                    destinationPath: destinationPath
                )
                if count > 0 {
                    syncProgress = "Sync complete!"
                    
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        await MainActor.run {
                            if syncProgress == "Sync complete!" {
                                syncProgress = nil
                            }
                        }
                    }
                }
                
                stopSyncProgressPolling()
                isSyncing = false
                syncCurrentPhoto = ""
                startMonitoring()
                return count
                
            } catch {
                let partialCount = syncProgressCurrent
                
                syncProgress = nil
                stopSyncProgressPolling()
                isSyncing = false
                syncCurrentPhoto = ""
                
                let errorMessage = error.localizedDescription
                let isDisconnectionError = errorMessage.contains("device offline") ||
                                           errorMessage.contains("device not found") ||
                                           errorMessage.contains("disconnected") ||
                                           errorMessage.contains("connect failed") ||
                                           errorMessage.contains("closed") ||
                                           errorMessage.contains("Failed to pull")
                
                if isDisconnectionError {
                    needsReconnection = true
                    isReconnecting = true
                    deviceConfirmedGone = false
                    partialSyncCount = partialCount > 0 ? partialCount : nil
                    disconnectedDeviceId = device.id
                    self.error = nil
                }
                self.error = errorMessage
                startMonitoring()
                return partialCount > 0 ? partialCount : nil
            }
        }


    
    private func startSyncProgressPolling() {
        syncProgressTask?.cancel()
        
        syncProgressTask = Task {
            while !Task.isCancelled {
                await updateSyncProgress()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }
    
    private func stopSyncProgressPolling() {
        syncProgressTask?.cancel()
        syncProgressTask = nil
    }
    
    private func updateSyncProgress() async {
        let progress = await client.getPhotoSyncProgress()
        
        if progress.total > 0 {
            syncProgress = "Syncing \(progress.current)/\(progress.total) photos..."
            syncCurrentCount = progress.current
            syncTotalCount = progress.total
            syncCurrentPhoto = progress.currentFile
        }
        syncProgressCurrent = progress.current
    }
    
    
    deinit {
        pollingTask?.cancel()
        client.invalidate()
    }
}
