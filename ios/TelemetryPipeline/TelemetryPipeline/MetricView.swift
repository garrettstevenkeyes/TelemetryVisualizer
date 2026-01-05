//
//  MetricView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI

struct MetricView: View {
    @State private var showingAddMetric = false
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 18) {
                        
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddMetric = true }) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(Color.eggshell)
                            .accessibilityLabel("Create metric")
                    }
                }
            }
            .sheet(isPresented: $showingAddMetric) {
                AddMetricView()
            }
        }
    }
}





#Preview {
    MetricView()
}

