//
//  ADBXPCService.swift
//  ADBXPCService
//
//  Created by rrft on 02/10/25.
//

import Foundation

@objc public protocol ADBServiceProtocol {
    func listDevices(completion: @escaping ([Device]?, Error?) -> Void)
    func getDeviceDetails(deviceId: String, completion: @escaping (Device?, Error?) -> Void)
    func startMonitoring()
    func stopMonitoring()
}
