//
//  ADBServiceImplementation.swift
//  XPCLibrary
//

import Foundation

public final class ADBServiceImplementation: NSObject, ADBServiceProtocol, @unchecked Sendable {
    
    private var cachedDevices: [Device] = []
    private var pollingTask: Task<Void, Never>?
    private let cacheLock = NSLock()
    private var cachedADBPath: String?
    private var syncProgressCurrent: Int = 0
    private var syncProgressTotal: Int = 0
    private let syncProgressLock = NSLock()
    private var syncProgressCurrentFile: String = ""
    
    public override init() {
        super.init()
    }
    
    
    public func listFolderContents(
        deviceId: String,
        path: String,
        completion: @escaping @Sendable ([[String: Any]]?, Error?) -> Void
    ) {
        Task {
            do {
                let items = try await listFolderContentsOnDevice(
                    deviceId: deviceId,
                    path: path
                )
                completion(items, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    private func listFolderContentsOnDevice(
        deviceId: String,
        path: String
    ) async throws -> [[String: Any]] {
        let adbPath = try getADBPath()
        
        var items: [[String: Any]] = []
        
        let dirOutput = try await runADBCommand(
            adbPath: adbPath,
            deviceId: deviceId,
            command: "shell",
            args: ["find", shellEscape(path), "-maxdepth", "1", "-type", "d"]
        )
        
        let allPaths = dirOutput
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { $0 != path }
        
        let folderNames = allPaths.map { ($0 as NSString).lastPathComponent }
        
        for folderName in folderNames {
            items.append([
                "type": "folder",
                "name": folderName,
                "photoCount": 0
            ])
        }
        
        items.sort { item1, item2 in
            let name1 = item1["name"] as! String
            let name2 = item2["name"] as! String
            return name1 < name2
        }
        
        return items
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
                let nsError = error as NSError
                let userInfo = [NSLocalizedDescriptionKey: error.localizedDescription]
                let wrappedError = NSError(
                    domain: nsError.domain,
                    code: nsError.code,
                    userInfo: userInfo
                )
                completion(nil, wrappedError)
            }
        }
    }

    
    public func getPhotoSyncProgress(completion: @escaping @Sendable (Int, Int, String) -> Void) {
        syncProgressLock.lock()
        let current = syncProgressCurrent
        let total = syncProgressTotal
        let file = syncProgressCurrentFile
        syncProgressLock.unlock()
        
        completion(current, total, file)
    }
    
    // MARK: - Private Helpers
    
    private func shellEscape(_ path: String) -> String {
        // Escape single quotes by replacing ' with '\''
        // Then wrap the whole thing in single quotes
        return "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
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
            args: ["getprop", "ro.product.marketname"]
        )
        
        if device.model == nil || device.model?.isEmpty == true {
            device.model = try? await runADBCommand(
                adbPath: adbPath,
                deviceId: deviceId,
                command: "shell",
                args: ["getprop", "ro.product.model"]
            )
        }
        
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
    
    private func performPhotoSync(
            deviceId: String,
            sourcePath: String,
            destinationPath: String
        ) async throws -> Int {
            let adbPath = try getADBPath()
            
            updateSyncProgress(current: 0, total: 0)
            
            let photoFiles = try await listPhotosOnDevice(
                adbPath: adbPath,
                deviceId: deviceId,
                sourcePath: sourcePath
            )
            
            guard !photoFiles.isEmpty else {
                throw ADBError.commandFailed("No photos found in this folder.\n\nPlease select a different folder with images.")
            }
            
            print("Found \(photoFiles.count) photos on device")
            
            try createDestinationFolder(at: destinationPath)
            
            let totalCount = photoFiles.count
            var processedCount = 0
            var actuallySyncedCount = 0
            
            updateSyncProgress(current: 0, total: totalCount)
            
            do {
                for photoFile in photoFiles {
                    let destinationFile = (destinationPath as NSString).appendingPathComponent(photoFile)
                    
                    processedCount += 1
                    
                    if FileManager.default.fileExists(atPath: destinationFile) {
                        print("Skipping \(photoFile) (already exists)")
                        updateSyncProgress(current: processedCount, total: totalCount, currentFile: "Skipped: \(photoFile)")
                        continue
                    }
                    
                    updateSyncProgress(current: processedCount, total: totalCount, currentFile: "Syncing: \(photoFile)")
                    
                    try await pullPhoto(
                        adbPath: adbPath,
                        deviceId: deviceId,
                        sourcePath: sourcePath,
                        fileName: photoFile,
                        destinationPath: destinationPath
                    )
                    
                    actuallySyncedCount += 1
                    updateSyncProgress(current: processedCount, total: totalCount, currentFile: "Completed: \(photoFile)")
                    print("Synced \(photoFile) (\(actuallySyncedCount) new, \(processedCount)/\(totalCount) processed)")
                }
                
                print("Sync complete! \(actuallySyncedCount) new photos synced")
                return actuallySyncedCount
                
            } catch {
                print("Sync interrupted: \(error.localizedDescription)")
                print("Partial sync: \(actuallySyncedCount) photos synced before interruption")
                
                updateSyncProgress(current: actuallySyncedCount, total: totalCount)
                
                throw error
            }
        }

    
    private func listPhotosOnDevice(
        adbPath: String,
        deviceId: String,
        sourcePath: String
    ) async throws -> [String] {
        let photoExtensions = ["jpg", "jpeg", "png", "heic", "dng", "raw"]
        var allPhotos: [String] = []
        
        for ext in photoExtensions {
            let output = try await runADBCommand(
                adbPath: adbPath,
                deviceId: deviceId,
                command: "shell",
                args: ["find", shellEscape(sourcePath), "-maxdepth", "1", "-type", "f", "-iname", "*.\(ext)"]
            )
            
            let photos = output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { ($0 as NSString).lastPathComponent }
            
            allPhotos.append(contentsOf: photos)
        }
        
        return Array(Set(allPhotos)).sorted()
    }
    
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
            
            if errorMessage.contains("device offline") ||
               errorMessage.contains("device not found") ||
               errorMessage.contains("no devices") {
                throw ADBError.deviceDisconnected
            }
            
            throw ADBError.commandFailed("Failed to pull \(fileName): \(errorMessage)")
        }
    }
    
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
    
    private func updateSyncProgress(current: Int, total: Int, currentFile: String = "") {
        syncProgressLock.lock()
        syncProgressCurrent = current
        syncProgressTotal = total
        syncProgressCurrentFile = currentFile
        syncProgressLock.unlock()
    }
}
