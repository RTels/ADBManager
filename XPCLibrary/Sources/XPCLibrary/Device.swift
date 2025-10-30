//
//  Device.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import Foundation

@objc(AndroidDevice)
public class Device: NSObject, NSSecureCoding, Identifiable, @unchecked Sendable {
    
    public let id: String
    public let state: DeviceState
    
    public var model: String?
    public var manufacturer: String?
    public var androidVersion: String?
    public var batteryLevel: String?
    public var apiLevel: String?
    

    public init(id: String, stateString: String) {
        self.id = id
        self.state = DeviceState(rawValue: stateString) ?? .unknown
        super.init()
    }
    
    public var displayName: String {
        if let model = model, !model.isEmpty {
            return model
        }
        
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            return manufacturer
        }
        
        return id
    }

    
    
    public static var supportsSecureCoding: Bool { true }
    
    public required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(of: NSString.self, forKey: "id") as String?,
              let stateRaw = coder.decodeObject(of: NSString.self, forKey: "state") as String? else {
            return nil
        }
        self.id = id
        self.state = DeviceState(rawValue: stateRaw) ?? .unknown
        
        self.model = coder.decodeObject(of: NSString.self, forKey: "model") as String?
        self.manufacturer = coder.decodeObject(of: NSString.self, forKey: "manufacturer") as String?
        self.androidVersion = coder.decodeObject(of: NSString.self, forKey: "androidVersion") as String?
        self.batteryLevel = coder.decodeObject(of: NSString.self, forKey: "batteryLevel") as String?
        self.apiLevel = coder.decodeObject(of: NSString.self, forKey: "apiLevel") as String?
        super.init()
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(id as NSString, forKey: "id")
        coder.encode(state.rawValue as NSString, forKey: "state")
        
        if let model = model { coder.encode(model as NSString, forKey: "model") }
        if let manufacturer = manufacturer { coder.encode(manufacturer as NSString, forKey: "manufacturer") }
        if let androidVersion = androidVersion { coder.encode(androidVersion as NSString, forKey: "androidVersion") }
        if let batteryLevel = batteryLevel { coder.encode(batteryLevel as NSString, forKey: "batteryLevel") }
        if let apiLevel = apiLevel { coder.encode(apiLevel as NSString, forKey: "apiLevel") }
    }
}

@objc public enum DeviceState: Int, RawRepresentable {
    case device
    case offline
    case unauthorized
    case unknown
    
    public var rawValue: String {
        switch self {
        case .device: return "device"
        case .offline: return "offline"
        case .unauthorized: return "unauthorized"
        case .unknown: return "unknown"
        }
    }
    
    public var displayName: String {
        switch self {
        case .device: return "Connected"
        case .unauthorized: return "Awaiting Pairing"
        case .offline, .unknown: return "Not Connected"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "device": self = .device
        case "offline": self = .offline
        case "unauthorized": self = .unauthorized
        default: self = .unknown
        }
    }
}
