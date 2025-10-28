//
//  ADBServiceClient.swift
//  XPCLibrary
//

import Foundation

/// Client for communicating with ADB XPC Service
/// Provides clean async/await API, hiding XPC callback complexity
public final class ADBServiceClient {
    
    private let connectionManager: XPCConnectionManager
    
    public init(connectionManager: XPCConnectionManager = XPCConnectionManager()) {
        self.connectionManager = connectionManager
    }
    
    // MARK: - Monitoring
    
    public func startMonitoring() {
        guard let service = connectionManager.getService() else { return }
        service.startMonitoring()
    }
    
    public func stopMonitoring() {
        guard let service = connectionManager.getService() else { return }
        service.stopMonitoring()
    }
    
    // MARK: - Device Operations
    
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
    
    // MARK: - Folder Operations
    
    public func listFolders(deviceId: String, path: String) async throws -> [String] {
        guard let service = getServiceWithErrorHandler() else {
            throw ADBServiceError.serviceUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            service.listFolders(
                deviceId: deviceId,
                path: path,
                completion: { folders, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let folders = folders {
                        continuation.resume(returning: folders)
                    } else {
                        continuation.resume(throwing: ADBServiceError.xpcError("No folders returned"))
                    }
                }
            )
        }
    }
    
    // MARK: - Photo Sync
    
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
    
    public func getPhotoSyncProgress() async -> (current: Int, total: Int) {
        guard let service = connectionManager.getService() else {
            return (0, 0)
        }
        
        return await withCheckedContinuation { continuation in
            service.getPhotoSyncProgress { current, total in
                continuation.resume(returning: (current, total))
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getServiceWithErrorHandler() -> ADBServiceProtocol? {
        return connectionManager.getServiceWithErrorHandler { error in
            print("XPC Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    public func invalidate() {
        connectionManager.invalidate()
    }
}
