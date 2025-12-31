//
//  AddMetricView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/30/25.
//

import SwiftUI

struct AddMetricView: View {
    @State private var name: String = ""
    @State private var unit: String = ""
    @State private var icon: MetricSymbol = .none

    init(icon: MetricSymbol = .none) {
        self._icon = State(initialValue: icon)
    }

    var body: some View {
        
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    AddMetricTopBlock(name: $name, unit: $unit, selectedIcon: $icon)
                    // other blocks (ranges, zone distribution, button) later…
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
            }
        }
        .paperBackground()
    }
}

#Preview {
    AddMetricView(icon: MetricSymbol.none)
}

