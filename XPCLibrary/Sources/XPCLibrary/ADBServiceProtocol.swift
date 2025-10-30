//
//  ADBServiceProtocol.swift
//  XPCLibrary
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
    func getPhotoSyncProgress(completion: @escaping @Sendable (Int, Int, String) -> Void)
    func listFolderContents(deviceId: String, path: String, completion: @escaping @Sendable ([[String: Any]]?, Error?) -> Void)  // ← NEW
}
