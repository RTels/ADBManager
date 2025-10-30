//
//  ADBServiceClient.swift
//  XPCLibrary
//

import Foundation

/// Client for communicating with ADB XPC Service

public final class ADBServiceClient {
    
    private let connectionManager: XPCConnectionManager
    
    public init(connectionManager: XPCConnectionManager = XPCConnectionManager()) {
        self.connectionManager = connectionManager
    }
    
    
    public func startMonitoring() {
        guard let service = connectionManager.getService() else { return }
        service.startMonitoring()
    }
    
    public func stopMonitoring() {
        guard let service = connectionManager.getService() else { return }
        service.stopMonitoring()
    }
    
    
    public func listDevices() async throws -> [Device] {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.listDevices { devices, error in
                if let error = error {
                    continuation.resume(throwing: ADBServiceError.xpcError(error.localizedDescription))
                } else if let devices = devices {
                    continuation.resume(returning: devices)
                } else {
                    continuation.resume(throwing: ADBServiceError.xpcError("No data returned"))
                }
            }
        }
    }
    
    public func getDeviceDetails(deviceId: String) async throws -> Device {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.getDeviceDetails(deviceId: deviceId) { device, error in
                if let error = error {
                    continuation.resume(throwing: ADBServiceError.xpcError(error.localizedDescription))
                } else if let device = device {
                    continuation.resume(returning: device)
                } else {
                    continuation.resume(throwing: ADBServiceError.xpcError("No data returned"))
                }
            }
        }
    }
    
    public func listFolderContents(deviceId: String, path: String) async throws -> [FolderItem] {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.listFolderContents(
                deviceId: deviceId,
                path: path,
                completion: { items, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let items = items {
                        let folderItems = items.compactMap { dict -> FolderItem? in
                            guard let type = dict["type"] as? String,
                                  let name = dict["name"] as? String else {
                                return nil
                            }
                            
                            if type == "folder" {
                                let count = dict["photoCount"] as? Int ?? 0
                                return .folder(name: name, photoCount: count)
                            } else {
                                return .photo(name: name)
                            }
                        }
                        continuation.resume(returning: folderItems)
                    } else {
                        continuation.resume(throwing: ADBServiceError.xpcError("No data returned"))
                    }
                }
            )
        }
    }
    
    public func startPhotoSync(
        deviceId: String,
        sourcePath: String,
        destinationPath: String
    ) async throws -> Int {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.startPhotoSync(
                deviceId: deviceId,
                sourcePath: sourcePath,
                destinationPath: destinationPath,
                completion: { count, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let count = count {
                        continuation.resume(returning: count.intValue)
                    } else {
                        continuation.resume(throwing: ADBServiceError.xpcError("No count returned"))
                    }
                }
            )
        }
    }
    
    public func getPhotoSyncProgress() async -> (current: Int, total: Int, currentFile: String) {
        guard let service = connectionManager.getService() else {
            return (0, 0, "")
        }
        
        return await withCheckedContinuation { continuation in
            service.getPhotoSyncProgress { current, total, file in
                continuation.resume(returning: (current, total, file))
            }
        }
    }
    
    private func getServiceWithErrorHandler() -> ADBServiceProtocol? {
        return connectionManager.getServiceWithErrorHandler { error in
            print("XPC Error: \(error.localizedDescription)")
        }
    }
    
    public func invalidate() {
        connectionManager.invalidate()
    }
}
