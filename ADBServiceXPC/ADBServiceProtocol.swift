//
//  adbXPCService.swift
//  adbXPCService
//
//  Created by rrft on 02/10/25.
//

import Foundation

@objc protocol ADBServiceProtocol {
    func listDevices(completion: @escaping ([AndroidDevice]?, Error?) -> Void)
    func getDeviceDetails(deviceId: String, completion: @escaping (AndroidDevice?, Error?) -> Void)
}


