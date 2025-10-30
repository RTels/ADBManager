//
//  FolderBrowserView.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary

struct FolderBrowserView: View {
    @ObservedObject var adbService: ADBService
    let device: Device
    @Binding var selectedPath: String?
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPath: String = "/sdcard/"
    @State private var items: [FolderItem] = []
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
                itemList
            }
            
            Divider()
            footer
        }
        .frame(width: 500, height: 400)
        .task {
            await loadItems()
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
    
    private var itemList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(items) { item in
                    FolderItemRow(item: item) {
                        if item.isFolder {
                            navigateInto(folder: item.name)
                        }
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
    
    private func loadItems() async {
        isLoading = true
        errorMessage = nil
        
        do {
            items = try await adbService.listFolderContents(for: device, at: currentPath)
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
            await loadItems()
        }
    }
    
    private func goBack() {
        guard pathHistory.count > 1 else { return }
        currentPath = pathHistory.removeLast()
        
        Task {
            await loadItems()
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
