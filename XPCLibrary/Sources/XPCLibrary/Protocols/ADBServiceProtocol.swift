//
//  ADBXPCService.swift
//  ADBXPCService
//
//  Created by rrft on 02/10/25.
//

import Foundation

@objc public protocol ADBServiceProtocol {
    func listDevices(completion: @escaping @Sendable ([Device]?, Error?) -> Void)
    func getDeviceDetails(deviceId: String, completion: @escaping @Sendable (Device?, Error?) -> Void)
    func startMonitoring()
    func stopMonitoring()
    func startPhotoSync(
        deviceId: String,
        sourcePath: String,      
        destinationPath: String,
        completion: @escaping @Sendable (NSNumber?, Error?) -> Void
    )
    func getPhotoSyncProgress(completion: @escaping @Sendable (Int, Int) -> Void)
    func listFolders(deviceId: String, path: String, completion: @escaping @Sendable ([String]?, Error?) -> Void)
}

