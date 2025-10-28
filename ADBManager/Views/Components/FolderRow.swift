//
//  FolderRow.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI

struct FolderRow: View {
    let folderName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                Text(folderName)
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
    FolderRow(folderName: "DCIM") {
        print("Tapped DCIM")
    }
}

