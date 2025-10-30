//
//  FolderItemRow.swift
//  ADBManager
//

import SwiftUI
import XPCLibrary

struct FolderItemRow: View {
    let item: FolderItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.title3)                 
                Text(item.name)
                    .font(.body)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        FolderItemRow(item: .folder(name: "DCIM", photoCount: 0)) {
            print("Tapped")
        }
    }
}
