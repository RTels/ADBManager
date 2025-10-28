//
//  MonitoringIndicator.swift
//  ADBManager
//
//  Created by rrft on 28/10/25.
//

import SwiftUI

struct MonitoringIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(isAnimating ? 0.3 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
            
            Text("Monitoring")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    MonitoringIndicator()
        .padding()
}
