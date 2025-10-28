//
//  FolderBrowserView.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI
import XPCLibrary

struct FolderBrowserView: View {
    @ObservedObject var adbService: ADBService
    let device: Device
    @Binding var selectedPath: String?
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPath: String = "/sdcard/"
    @State private var folders: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pathHistory: [String] = ["/sdcard/"]
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            navigationBar
            Divider()
            
            if let error = errorMessage {
                errorView(error: error)
            } else {
                folderList
            }
            
            Divider()
            footer
        }
        .frame(width: 500, height: 400)
        .task {
            await loadFolders()
        }
    }
    
    private var header: some View {
        HStack {
            Text("Browse Device Folders")
                .font(.headline)
            Spacer()
            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var navigationBar: some View {
        HStack {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(pathHistory.count <= 1)
            
            Text(currentPath)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding()
    }
    
    private var folderList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(folders, id: \.self) { folder in
                    FolderRow(folderName: folder) {
                        navigateInto(folder: folder)
                    }
                }
            }
        }
    }
    
    private func errorView(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var footer: some View {
        HStack {
            Text("Selected: \(currentPath)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Select This Folder") {
                selectedPath = currentPath
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func loadFolders() async {
        isLoading = true
        errorMessage = nil
        
        do {
            folders = try await adbService.listFolders(for: device, at: currentPath)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func navigateInto(folder: String) {
        var newPath = (currentPath as NSString).appendingPathComponent(folder)
        if !newPath.hasSuffix("/") {
            newPath += "/"
        }
        
        pathHistory.append(currentPath)
        currentPath = newPath
        
        Task {
            await loadFolders()
        }
    }
    
    private func goBack() {
        guard pathHistory.count > 1 else { return }
        currentPath = pathHistory.removeLast()
        
        Task {
            await loadFolders()
        }
    }
}

#Preview {
    FolderBrowserView(
        adbService: ADBService(),
        device: Device(id: "test123", stateString: "device"),
        selectedPath: .constant("/sdcard/")
    )
}

