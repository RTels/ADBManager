//
//  ADBUtilities.swift
//  XPCLibrary
//
//  Created by rrft on 23/10/25.
//

import Foundation

/// Utility functions for ADB operations
public enum ADBUtilities {
    
    /// Get path to bundled adb executable
    /// - Returns: Full path to adb binary
    /// - Throws: ADBError.adbNotFound if binary not in package resources
    public static func getADBPath() throws -> String {
        // Bundle.module works here because we're INSIDE the package
        guard let path = Bundle.module.path(forResource: "adb", ofType: nil) else {
            throw ADBError.adbNotFound
        }
        
        try ensureExecutable(at: path)
        
        return path
    }
    
    /// Set executable permissions on file
    private static func ensureExecutable(at path: String) throws {
        let fileManager = FileManager.default
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: path
        )
    }
}

/// Errors that can occur during ADB operations
public enum ADBError: Error, LocalizedError {
    case adbNotFound
    case invalidOutput
    case commandFailed(String)
    case deviceDisconnected  // ← NEW
    
    public var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "ADB executable not found in package resources"
        case .invalidOutput:
            return "Could not decode ADB command output"
        case .commandFailed(let message):
            return "ADB command failed: \(message)"
        case .deviceDisconnected:
            return "Device disconnected during operation"
        }
    }
}

