//
//  InfoRow.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    InfoRow(label: "Model", value: "Pixel 6")
        .padding()
}
