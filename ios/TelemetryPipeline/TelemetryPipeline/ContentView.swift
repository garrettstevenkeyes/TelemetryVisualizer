//
//  ContentView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isSelectingForDeletion = false
    @State private var showingAddMetric = false
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 18) {
                        GenericMetricTile(
                            metricName: "Temperature",
                            metricReading: 72.5,
                            unit: "ºC",
                            status: .normal,
                            iconName: "Thermometer" // from your assets
                        )

                        GenericMetricTile(
                            metricName: "Pressure",
                            metricReading: 105.4,
                            unit: " kPa",
                            status: .warning,
                            iconName: "Gauge"
                        )

                        GenericMetricTile(
                            metricName: "Vibration",
                            metricReading: 5.8,
                            unit: " mm/s",
                            status: .alert,
                            iconName: "Vibration"
                        )
                    }
                    .padding(.horizontal, 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { isSelectingForDeletion.toggle() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(Color.eggshell)
                            .accessibilityLabel(isSelectingForDeletion ? "Exit selection" : "Select metrics")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Metrics")
                        .font(.title2)
                        .foregroundStyle(Color.eggshell)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddMetric = true }) {
                        Label("Create Metric", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(Color.eggshell)
                    }
                }
            }
            .sheet(isPresented: $showingAddMetric) {
                AddMetricView()
            }
        }
    }
}

struct GenericMetricTile: View {
    // Inputs for display
    let metricName: String
    let metricReading: Float
    let unit: String
    let status: MetricStatus
    let iconName: String? // Optional per-metric icon, e.g. thermometer, gauge, waveform

    // Theme
    private let navy = Color.eggshell
    private let cardFill = Color.white.opacity(0.22)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: name + status pill
            HStack {
                Text(metricName)
                    .font(.headline)
                    .foregroundStyle(navy)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: status.symbolName)
                        .foregroundStyle(status.color)
                    Text(status.label)
                        .font(.subheadline)
                        .foregroundStyle(status.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(status.color.opacity(0.18))
                )
            }

            // Reading row: big number + unit and optional icon
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(format: "%.1f", metricReading))\(unit)")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(navy)

                    // Secondary status text (optional)
                    Text(status.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let iconName {
                    Image(iconName) // Use asset name for custom PNG, or swap to SF Symbol if needed
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.18))
                        )
                        .squiggleBorder(
                            color: navy.opacity(0.8),
                            lineWidth: 2.5,
                            cornerRadius: 12,
                            amplitude: 2.0,
                            wavelength: 16
                        )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardFill)
        )
        .squiggleCardBorder()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(metricName) \(metricReading) \(unit), status \(status.label)")
    }
}


#Preview {
    ContentView()
}

