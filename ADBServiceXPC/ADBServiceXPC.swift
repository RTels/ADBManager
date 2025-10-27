//
//  ADBXPCService.swift
//  ADBServiceXPC
//
//  Created by rrft on 02/10/25.
//

import Foundation
import XPCLibrary

/// XPC Service wrapper that delegates to package implementation
class ADBXPCService: NSObject {
    private let implementation = ADBServiceImplementation()
}

// MARK: - Protocol Conformance (Delegate Everything)

extension ADBXPCService: ADBServiceProtocol {
    func listFolders(deviceId: String, path: String, completion: @escaping @Sendable ([String]?, (any Error)?) -> Void) {
        implementation.listFolders(deviceId: deviceId, path: path, completion: completion)
    }
    
    func getDeviceDetails(deviceId: String, completion: @escaping @Sendable (XPCLibrary.Device?, (any Error)?) -> Void) {
        implementation.getDeviceDetails(deviceId: deviceId, completion: completion)
    }
    
    func startMonitoring() {
        implementation.startMonitoring()
    }
    
    func stopMonitoring() {
        implementation.stopMonitoring()
    }
    
    func listDevices(completion: @escaping ([Device]?, Error?) -> Void) {
        implementation.listDevices(completion: completion)
    }
    
    func startPhotoSync(
        deviceId: String,
        sourcePath: String,       
        destinationPath: String,
        completion: @escaping @Sendable (NSNumber?, Error?) -> Void
    ) {
        implementation.startPhotoSync(
            deviceId: deviceId,
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            completion: completion
        )
    }

    
    func getPhotoSyncProgress(completion: @escaping @Sendable (Int, Int) -> Void) {
        implementation.getPhotoSyncProgress(completion: completion)
    }
}


