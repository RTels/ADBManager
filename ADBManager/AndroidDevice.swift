//
//  Device.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//

import Foundation

// WHY: XPC needs consistent class names across processes
@objc(AndroidDevice)
// WHY: XPC requires NSObject, NSSecureCoding for safe serialization
class AndroidDevice: NSObject, NSSecureCoding, Identifiable {
    
    // CORE: Always present from initial ADB scan
    let id: String
    let state: DeviceState
    
    // LAZY: Fetched on-demand when user clicks device
    var model: String?
    var manufacturer: String?
    var androidVersion: String?
    var batteryLevel: String?
    var apiLevel: String?
    
    // BASIC: Creates device from ADB output line
    init(id: String, stateString: String) {
        self.id = id
        self.state = DeviceState(rawValue: stateString) ?? .unknown
        super.init()
    }
    
    // UI: Fallback display before details load
    var displayName: String {
        let stateText = state == .device ? "Connected" : state.rawValue.capitalized
        return "\(id) - \(stateText)"
    }
    
    // MARK: - NSSecureCoding
    
    // SECURITY: Required for XPC - prevents arbitrary class injection
    static var supportsSecureCoding: Bool { true }
    
    // DESERIALIZE: Receives data from XPC → creates object
    // WHY failable?: Reject if data is corrupted/tampered
    required init?(coder: NSCoder) {
        // SECURITY: Verify exact types before decoding
        guard let id = coder.decodeObject(of: NSString.self, forKey: "id") as String?,
              let stateRaw = coder.decodeObject(of: NSString.self, forKey: "state") as String? else {
            return nil
        }
        self.id = id
        self.state = DeviceState(rawValue: stateRaw) ?? .unknown
        
        // OPTIONAL: These might not exist yet
        self.model = coder.decodeObject(of: NSString.self, forKey: "model") as String?
        self.manufacturer = coder.decodeObject(of: NSString.self, forKey: "manufacturer") as String?
        self.androidVersion = coder.decodeObject(of: NSString.self, forKey: "androidVersion") as String?
        self.batteryLevel = coder.decodeObject(of: NSString.self, forKey: "batteryLevel") as String?
        self.apiLevel = coder.decodeObject(of: NSString.self, forKey: "apiLevel") as String?
        super.init()
    }
    
    // SERIALIZE: Converts object → data for XPC transmission
    func encode(with coder: NSCoder) {
        coder.encode(id as NSString, forKey: "id")
        coder.encode(state.rawValue as NSString, forKey: "state")
        
        // CONDITIONAL: Only encode if value exists
        if let model = model { coder.encode(model as NSString, forKey: "model") }
        if let manufacturer = manufacturer { coder.encode(manufacturer as NSString, forKey: "manufacturer") }
        if let androidVersion = androidVersion { coder.encode(androidVersion as NSString, forKey: "androidVersion") }
        if let batteryLevel = batteryLevel { coder.encode(batteryLevel as NSString, forKey: "batteryLevel") }
        if let apiLevel = apiLevel { coder.encode(apiLevel as NSString, forKey: "apiLevel") }
    }
}

// WHY @objc + Int?: Objective-C compatibility for XPC (research: @objc enum requirements)
// WHY RawRepresentable?: Custom String raw values despite Int backing
@objc enum DeviceState: Int, RawRepresentable {
    // BACKING: Objective-C sees these as 0, 1, 2, 3
    case device
    case offline
    case unauthorized
    case unknown
    
    // STORAGE: What ADB actually returns (String)
    var rawValue: String {
        switch self {
        case .device: return "device"
        case .offline: return "offline"
        case .unauthorized: return "unauthorized"
        case .unknown: return "unknown"
        }
    }
    
    // UI: User-friendly labels
    var displayName: String {
        switch self {
        case .device: return "Connected"
        case .unauthorized: return "Awaiting Pairing"
        case .offline, .unknown: return "Not Connected"
        }
    }
    
    // PARSING: Converts ADB string → enum case
    init?(rawValue: String) {
        switch rawValue {
        case "device": self = .device
        case "offline": self = .offline
        case "unauthorized": self = .unauthorized
        default: self = .unknown
        }
    }
}
