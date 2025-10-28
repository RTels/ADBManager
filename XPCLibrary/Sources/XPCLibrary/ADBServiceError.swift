

import Foundation


public enum ADBServiceError: LocalizedError {
    case noConnection
    case serviceUnavailable
    case xpcError(String)
    
    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "XPC connection not established"
        case .serviceUnavailable:
            return "Could not connect to XPC service"
        case .xpcError(let message):
            return message
        }
    }
}
