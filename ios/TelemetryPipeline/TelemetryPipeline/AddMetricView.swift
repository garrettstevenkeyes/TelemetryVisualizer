//
//  AddMetricView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/30/25.
//

import SwiftUI

struct AddMetricView: View {
    let onSave: (Metric) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var unit: String = ""
    @State private var icon: MetricSymbol = .none
    @State private var goodMin: Float = 0
    @State private var goodMax: Float = 0
    @State private var okayMin: Float = 0
    @State private var okayMax: Float = 0
    @State private var badMin: Float = 0
    @State private var badMax: Float = 0
    @State private var percentBadThreshold: Float = 0

    init(icon: MetricSymbol = .none, onSave: @escaping (Metric) -> Void = { _ in }) {
        self.onSave = onSave
        self._icon = State(initialValue: icon)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 18) {
                        AddMetricTopBlock(name: $name, description: $description, unit: $unit, selectedIcon: $icon)
                        AddMetricRange(rangeMin: $goodMin, rangeMax: $goodMax, type: .good)
                        AddMetricRange(rangeMin: $okayMin, rangeMax: $okayMax, type: .okay)
                        AddMetricRange(rangeMin: $badMin, rangeMax: $badMax, type: .bad)
                        PercentBadAlarm(percentBadThreshold: $percentBadThreshold)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 0)
                }
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Create Metric")
                        .font(.headline)
                        .foregroundStyle(Color.eggshell)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(Color.eggshell)
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let metric = Metric(
                            id: UUID(),
                            metricName: name,
                            metricIcon: MetricIcon(rawValue: icon.rawValue) ?? .thermometer,
                            metricUnit: unit,
                            metricGoodRangeMin: Double(goodMin),
                            metricGoodRangeMax: Double(goodMax),
                            metricOkayRangeMin: Double(okayMin),
                            metricOkayRangeMax: Double(okayMax),
                            metricBadRangeMin: Double(badMin),
                            metricBadRangeMax: Double(badMax),
                            metricZonePercentGood: 0,
                            metricZonePercentOkay: 0,
                            metricZonePercentBad: 0,
                            metricValue: 0
                        )
                        self.onSave(metric)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(Color.eggshell)
                    .accessibilityLabel("Save metric")
                }
            }
        }
        
    }
}

struct AddMetricTopBlock: View {
    // Inputs you’ll later send to your backend
    @Binding var name: String
    @Binding var description: String
    @Binding var unit: String
    @Binding var selectedIcon: MetricSymbol

    // Theme colors (match your mock)
    private let navy = Color.eggshell
    private let cardFill = Color.white.opacity(0.22)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // NAME
            Text("Name")
                .font(.headline)
                .foregroundStyle(navy)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .accessibilityLabel("Metric name")
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                )
            
            // NAME
            Text("Description")
                .font(.headline)
                .foregroundStyle(navy)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", text: $description)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .accessibilityLabel("Metric description")
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                )

            // ICON PICKER
            Text("Icon")
                .font(.headline)
                .foregroundStyle(navy)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 14) {
                ForEach(MetricSymbol.allCases) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(selectedIcon == icon ? 0.35 : 0.18))

                            if icon == .none {
                                VStack {
                                    Image(systemName: "slash.circle")
                                        .font(.system(size: 28, weight: .regular))
                                        .foregroundStyle(navy.opacity(0.8))
                                    Text("")
                                        .font(.footnote)
                                        .foregroundStyle(navy.opacity(0.9))
                                }
                                .padding(14)
                            } else {
                                Image(icon.assetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(4)
                            }
                        }
                        .frame(height: 96)
                        .squiggleBorder(
                            color: navy.opacity(selectedIcon == icon ? 1.0 : 0.65),
                            lineWidth: selectedIcon == icon ? 3.5 : 3,
                            cornerRadius: 18,
                            amplitude: 2.4,
                            wavelength: 18
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(icon.rawValue))
                }
            }
            .padding(.vertical, 4)

            // UNIT
            Text("Unit")
                .font(.headline)
                .foregroundStyle(navy)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("", text: $unit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Metric unit")
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                )
            
            Text("Enter metric details including name, description, unit and icon.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardFill)
        )
        .squiggleCardBorder()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Metric details")
        .accessibilityHint("Enter the metric name, description, unit, and select an icon.")
    }
}

struct AddMetricRange: View {
    // Inputs you’ll later send to your backend
    @Binding var rangeMin: Float
    @Binding var rangeMax: Float
    let type: RangeType
    
    // Theme colors (match your mock)
    private let navy = Color.eggshell
    private let cardFill = Color.white.opacity(0.22)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(type.rawValue.capitalized) Range")
                .font(.headline)
                .foregroundStyle(navy)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Min")
                        .font(.caption)
                        .foregroundStyle(navy)

                    TextField("", value: $rangeMin, format: .number)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Minimum \(type.rawValue) value")
                        .accessibilityValue("\(rangeMin)")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Max")
                        .font(.caption)
                        .foregroundStyle(navy)

                    TextField("", value: $rangeMax, format: .number)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Maximum \(type.rawValue) value")
                        .accessibilityValue("\(rangeMax)")
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        )
                }
            }
            Text("Enter the acceptable range for this metric.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardFill)
        )
        .squiggleCardBorder()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(type.rawValue.capitalized) range")
        .accessibilityHint("Enter minimum and maximum acceptable values for this metric.")
    }
}

struct PercentBadAlarm: View {
    // Inputs you’ll later send to your backend
    @Binding var percentBadThreshold: Float
    
    // Theme colors (match your mock)
    private let navy = Color.eggshell
    private let cardFill = Color.white.opacity(0.22)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unhealthy Data Threshold")
                .font(.headline)
                .foregroundStyle(navy)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Alert when unhealthy data ≥")
                        .font(.caption)
                        .foregroundStyle(navy)

                    HStack(spacing: 8) {
                        TextField("", value: $percentBadThreshold, format: .number)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Alert when unhealthy data is greater than or equal to")
                            .accessibilityValue("\(percentBadThreshold)")
                            .accessibilityHint("A notification will be delivered once this threshold is crossed.")
                            .submitLabel(.done)
                        Text("%")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(navy)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(navy.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    )
                }
            }
            Text("Set the percentage of datapoints considered unhealthy that triggers an alert.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardFill)
        )
        .squiggleCardBorder()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Unhealthy Data Threshold")
        .accessibilityHint("Set the percentage threshold that triggers a notification.")
    }
}

enum MetricSymbol: String, CaseIterable, Identifiable {
    case none, thermometer, gauge, waveform
    var id: String { rawValue }

    // If you're using your custom PNGs, add them to Assets.xcassets with these names.
    var assetName: String {
        switch self {
        case .none: return ""
        case .thermometer: return "Thermometer"
        case .gauge: return "Gauge"
        case .waveform: return "Vibration"
        }
    }
}

enum RangeType: String, CaseIterable, Identifiable {
    case good, okay, bad
    var id: String { rawValue }

    // If you're using your custom PNGs, add them to Assets.xcassets with these names.
    var assetName: String {
        switch self {
        case .good: return "Good"
        case .okay: return "Okay"
        case .bad: return "Bad"
        }
    }
}

#Preview {
    AddMetricView(icon: MetricSymbol.none, onSave: { _ in })
}

