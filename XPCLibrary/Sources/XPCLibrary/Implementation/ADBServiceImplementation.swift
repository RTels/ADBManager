
//
//  ADBServiceImplementation.swift
//  XPCLibrary
//


import Foundation

public final class ADBServiceImplementation: NSObject, ADBServiceProtocol, @unchecked Sendable {
 
    
    public func listFolders(
        deviceId: String,
        path: String,
        completion: @escaping @Sendable ([String]?, Error?) -> Void
    ) {
        Task {
            do {
                let folders = try await listFoldersOnDevice(
                    deviceId: deviceId,
                    path: path
                )
                completion(folders, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    
    private var cachedDevices: [Device] = []
    private var pollingTask: Task<Void, Never>?
    private let cacheLock = NSLock()
    private var cachedADBPath: String?
    private var syncProgressCurrent: Int = 0
    private var syncProgressTotal: Int = 0
    private let syncProgressLock = NSLock()
    
    public override init() {
        super.init()
    }
    
    
    public func startMonitoring() {
        pollingTask?.cancel()
        
        pollingTask = Task {
            while !Task.isCancelled {
                await pollDevices()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    public func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    public func listDevices(completion: @escaping ([Device]?, Error?) -> Void) {
        let devices = getCache()
        completion(devices, nil)
    }
    
    public func getDeviceDetails(deviceId: String, completion: @escaping @Sendable (Device?, Error?) -> Void) {
        Task {
            do {
                let device = try await fetchDeviceDetails(deviceId: deviceId)
                completion(device, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    public func startPhotoSync(
        deviceId: String,
        sourcePath: String,
        destinationPath: String,
        completion: @escaping @Sendable (NSNumber?, Error?) -> Void
    ) {
        Task {
            do {
                let count = try await performPhotoSync(
                    deviceId: deviceId,
                    sourcePath: sourcePath,
                    destinationPath: destinationPath
                )
                completion(NSNumber(value: count), nil)
            } catch {
                completion(nil, error)
            }
        }
    }




    public func getPhotoSyncProgress(completion: @escaping @Sendable (Int, Int) -> Void) {
        syncProgressLock.lock()
        let current = syncProgressCurrent
        let total = syncProgressTotal
        syncProgressLock.unlock()
        
        completion(current, total)
    }
        
    private func pollDevices() async {
        do {
            let devices = try await performListDevices()
            updateCache(devices)
        } catch {
            print("Polling failed: \(error)")
        }
    }
    
    private func getADBPath() throws -> String {
        if let cached = cachedADBPath {
            return cached
        }
        
        let path = try ADBUtilities.getADBPath()
        cachedADBPath = path
        return path
    }
    
    private func performListDevices() async throws -> [Device] {
        let adbPath = try getADBPath()
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["devices"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ADBError.invalidOutput
        }
        
        let basicDevices = parseADBOutput(output)
        
        var detailedDevices: [Device] = []
        
        for device in basicDevices {
            if device.state == .device {
                do {
                    let detailed = try await fetchDeviceDetails(deviceId: device.id)
                    detailedDevices.append(detailed)
                } catch {
                    print("Failed to fetch details for \(device.id): \(error)")
                    detailedDevices.append(device)
                }
            } else {
                detailedDevices.append(device)
            }
        }
        
        return detailedDevices
    }
    
    private func fetchDeviceDetails(deviceId: String) async throws -> Device {
        let adbPath = try getADBPath()
        
        let device = Device(id: deviceId, stateString: "device")
        
        device.model = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.product.model"]
        )
        
        device.manufacturer = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.product.manufacturer"]
        )
        
        device.androidVersion = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.build.version.release"]
        )
        
        device.apiLevel = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["getprop", "ro.build.version.sdk"]
        )
        
        if let batteryOutput = try? await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["dumpsys", "battery"]
        ) {
            device.batteryLevel = parseBatteryLevel(from: batteryOutput)
        }
        
        return device
    }
    
    private func runADBCommand(adbPath: String, deviceId: String, command: String, args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["-s", deviceId, command] + args
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw ADBError.invalidOutput
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseBatteryLevel(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("level:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces) + "%"
                }
            }
        }
        return nil
    }
    
    private func parseADBOutput(_ output: String) -> [Device] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> Device? in
                guard !line.isEmpty,
                      !line.contains("List of devices") else {
                    return nil
                }
                
                let components = line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                guard components.count >= 2 else {
                    return nil
                }
                
                return Device(id: components[0], stateString: components[1])
            }
    }
    
    private func updateCache(_ devices: [Device]) {
        cacheLock.lock()
        cachedDevices = devices
        cacheLock.unlock()
    }
    
    private func getCache() -> [Device] {
        cacheLock.lock()
        let devices = cachedDevices
        cacheLock.unlock()
        return devices
    }
    
    // MARK: - Photo Sync Implementation

    /// Main photo sync logic
    private func performPhotoSync(
        deviceId: String,
        sourcePath: String,
        destinationPath: String
    ) async throws -> Int {
        let adbPath = try getADBPath()
        
        let photoFiles = try await listPhotosOnDevice(
            adbPath: adbPath,
            deviceId: deviceId,
            sourcePath: sourcePath
        )
        
        guard !photoFiles.isEmpty else {
            print("No photos found on device")
            return 0
        }
        
        print("Found \(photoFiles.count) photos on device")
        
        try createDestinationFolder(at: destinationPath)
        
        let totalCount = photoFiles.count
        var processedCount = 0
        var actuallySyncedCount = 0
        
        updateSyncProgress(current: 0, total: totalCount)
        
        // Track partial progress even on failure
        do {
            for photoFile in photoFiles {
                let destinationFile = (destinationPath as NSString).appendingPathComponent(photoFile)
                
                processedCount += 1
                
                if FileManager.default.fileExists(atPath: destinationFile) {
                    print("Skipping \(photoFile) (already exists)")
                    updateSyncProgress(current: processedCount, total: totalCount)
                    continue
                }
                
                try await pullPhoto(
                    adbPath: adbPath,
                    deviceId: deviceId,
                    sourcePath: sourcePath,
                    fileName: photoFile,
                    destinationPath: destinationPath
                )
                
                actuallySyncedCount += 1
                updateSyncProgress(current: processedCount, total: totalCount)
                print("Synced \(photoFile) (\(actuallySyncedCount) new, \(processedCount)/\(totalCount) processed)")
            }
            
            print("Sync complete! \(actuallySyncedCount) new photos synced")
            return actuallySyncedCount
            
        } catch {
            // On error, return partial count
            print("Sync interrupted: \(error.localizedDescription)")
            print("Partial sync: \(actuallySyncedCount) photos synced before interruption")
            
            // Update final progress with partial count
            updateSyncProgress(current: actuallySyncedCount, total: totalCount)
            
            throw error  // Re-throw with partial count saved
        }
    }


    /// List photos in device's DCIM/Camera folder
    private func listPhotosOnDevice(
        adbPath: String,
        deviceId: String,
        sourcePath: String        // ← NEW
    ) async throws -> [String] {
        let output = try await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["ls", sourcePath]   // ← Use dynamic path
        )
        
        let files = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { isPhotoFile($0) }
        
        return files
    }


    /// Check if filename is a photo (by extension)
    private func isPhotoFile(_ filename: String) -> Bool {
        let photoExtensions = ["jpg", "jpeg", "png", "heic", "dng", "raw"]
        let ext = (filename as NSString).pathExtension.lowercased()
        return photoExtensions.contains(ext)
    }

    /// Pull a single photo from device
    private func pullPhoto(
        adbPath: String,
        deviceId: String,
        sourcePath: String,
        fileName: String,
        destinationPath: String
    ) async throws {
        let fullSourcePath = (sourcePath as NSString).appendingPathComponent(fileName)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["-s", deviceId, "pull", fullSourcePath, destinationPath]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            
            // DETECT: Device disconnection
            if errorMessage.contains("device offline") ||
               errorMessage.contains("device not found") ||
               errorMessage.contains("no devices") {
                throw ADBError.deviceDisconnected  // ← Specific error
            }
            
            throw ADBError.commandFailed("Failed to pull \(fileName): \(errorMessage)")
        }
    }

    /// Create destination folder if it doesn't exist
    private func createDestinationFolder(at path: String) throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("Created destination folder: \(path)")
        }
    }
    
    private func updateSyncProgress(current: Int, total: Int) {
        syncProgressLock.lock()
        syncProgressCurrent = current
        syncProgressTotal = total
        syncProgressLock.unlock()
    }
    
    /// List all folders (directories) at given path on device
    private func listFoldersOnDevice(
        deviceId: String,
        path: String
    ) async throws -> [String] {
        let adbPath = try getADBPath()
        
        // Use 'find' command to list only directories
        let output = try await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["find", path, "-maxdepth", "1", "-type", "d"]
        )
        
        // Parse output - one path per line
        let allPaths = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { $0 != path }  // Exclude current directory
        
        // Extract just the folder names (not full paths)
        let folders = allPaths.map { fullPath in
            (fullPath as NSString).lastPathComponent
        }
        .sorted()
        
        return folders
    }



    
    
}

