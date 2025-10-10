//
//  Device.swift
//  ADBManager
//
//  Created by rrft on 02/10/25.
//



import Foundation

@objc(AndroidDevice)
class AndroidDevice: NSObject, NSSecureCoding, Identifiable {
    let id: String
    let state: DeviceState
    
    init(id: String, stateString: String) {
        self.id = id
        self.state = DeviceState(rawValue: stateString) ?? .unknown
        super.init()
    }
    
    var displayName: String {
        let stateText = state == .device ? "Connected" : state.rawValue.capitalized
        return "\(id) - \(stateText)"
    }
    
    // MARK: - NSSecureCoding
    
    static var supportsSecureCoding: Bool { true }
    
    required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(of: NSString.self, forKey: "id") as String?,
              let stateRaw = coder.decodeObject(of: NSString.self, forKey: "state") as String? else {
            return nil
        }
        self.id = id
        self.state = DeviceState(rawValue: stateRaw) ?? .unknown
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(id as NSString, forKey: "id")
        coder.encode(state.rawValue as NSString, forKey: "state")
    }
}

@objc enum DeviceState: Int, RawRepresentable {
    case device
    case offline
    case unauthorized
    case unknown
    
    var rawValue: String {
        switch self {
        case .device: return "device"
        case .offline: return "offline"
        case .unauthorized: return "unauthorized"
        case .unknown: return "unknown"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "device": self = .device
        case "offline": self = .offline
        case "unauthorized": self = .unauthorized
        default: self = .unknown
        }
    }
}
