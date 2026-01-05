//
//  ContentView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI

private func status(for metric: Metric) -> MetricStatus {
    let v = metric.metricValue
    if v >= metric.metricBadRangeMin && v <= metric.metricBadRangeMax { return .alert }
    if v >= metric.metricOkayRangeMin && v <= metric.metricOkayRangeMax { return .warning }
    return .normal
}

/// Returns the string raw value when the value is a RawRepresentable with String raw value.
private func stringRawValue<T: RawRepresentable>(_ value: T) -> String? where T.RawValue == String {
    value.rawValue
}

/// Fallback overload: when the type isn't a RawRepresentable<String>, return nil.
private func stringRawValue(_ value: Any) -> String? { nil }

struct MetricSummary: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let status: MetricStatus
}

struct ContentView: View {
    @State private var isSelectingForDeletion = false
    @State private var showingAddMetric = false
    @State private var savedMetrics: [Metric] = []
    @State private var selectedMetricIDs: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    private var metricSummaries: [MetricSummary] {
        savedMetrics.map { metric in
            let s: MetricStatus = metric.isActive ? status(for: metric) : .inactive
            return MetricSummary(name: metric.metricName, status: s)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 18) {
                        if !metricSummaries.isEmpty {
                            MetricsOverview(metrics: metricSummaries)
                                .padding(.top, 4)
                        }

//                        GenericMetricTile(
//                            metricName: "Temperature",
//                            metricReading: 72.5,
//                            unit: "ºC",
//                            status: .normal,
//                            iconName: "Thermometer" // from your assets
//                        )
//
//                        GenericMetricTile(
//                            metricName: "Pressure",
//                            metricReading: 105.4,
//                            unit: " kPa",
//                            status: .warning,
//                            iconName: "Gauge"
//                        )
//
//                        GenericMetricTile(
//                            metricName: "Vibration",
//                            metricReading: 5.8,
//                            unit: " mm/s",
//                            status: .alert,
//                            iconName: "Vibration"
//                        )
                        
                        ForEach(savedMetrics) { metric in
                            ZStack(alignment: .topTrailing) {
                                GenericMetricTile(
                                    metricName: metric.metricName,
                                    metricReading: Float(metric.metricValue),
                                    unit: " \(metric.metricUnit)",
                                    status: metric.isActive ? status(for: metric) : nil,
                                    iconName: metric.metricIcon.assetName
                                )
                                if isSelectingForDeletion {
                                    Image(systemName: selectedMetricIDs.contains(metric.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedMetricIDs.contains(metric.id) ? Color.green : Color.gray.opacity(0.7))
                                        .padding(.top, 12)      // move further down
                                        .padding(.trailing, 12) // move further left
                                        .contentShape(Rectangle())
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelectingForDeletion {
                                    if selectedMetricIDs.contains(metric.id) {
                                        selectedMetricIDs.remove(metric.id)
                                    } else {
                                        selectedMetricIDs.insert(metric.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isSelectingForDeletion.toggle()
                        if !isSelectingForDeletion { selectedMetricIDs.removeAll() }
                    }) {
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
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectingForDeletion {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .font(.headline)
                        .foregroundStyle(Color.red)
                        .disabled(selectedMetricIDs.isEmpty)
                        .accessibilityLabel("Delete selected metrics")
                    }
                }
            }
            .sheet(isPresented: $showingAddMetric) {
                AddMetricView { newMetric in
                    savedMetrics.append(newMetric)
                }
            }
            .confirmationDialog(
                "Delete selected metrics?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    savedMetrics.removeAll { selectedMetricIDs.contains($0.id) }
                    selectedMetricIDs.removeAll()
                    isSelectingForDeletion = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
}

struct GenericMetricTile: View {
    // Inputs for display
    let metricName: String
    let metricReading: Float
    let unit: String
    let status: MetricStatus?
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
                if let status {
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
                } else {
                    // Inactive tag when there’s no active status
                    HStack(spacing: 6) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundStyle(Color.gray)
                        Text("Inactive")
                            .font(.subheadline)
                            .foregroundStyle(Color.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.gray.opacity(0.18))
                    )
                }
            }

            // Reading row: big number + unit and optional icon
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(format: "%.1f", metricReading))\(unit)")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(navy)

                    // Secondary status text (optional)
                    if let status {
                        Text(status.label)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(status.color)
                    }
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
        .opacity(status == nil ? 0.5 : 1.0)
        .squiggleCardBorder()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(status == nil ? "\(metricName) \(metricReading) \(unit), inactive" : "\(metricName) \(metricReading) \(unit), status \(status!.label)")
    }
}

struct MetricsOverview: View {
    let metrics: [MetricSummary]
    private let navy = Color.eggshell
    private let cardFill = Color.white.opacity(0.22)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dashboard")
                    .font(.headline)
                    .foregroundStyle(navy)
                Spacer()
            }

            FlowLayout(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(metrics) { metric in
                    MetricPill(name: metric.name, status: metric.status)
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
        .accessibilityLabel("Overview of metrics and statuses")
    }
}

struct MetricPill: View {
    let name: String
    let status: MetricStatus

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.symbolName)
                .foregroundStyle(status.color)
            Text(name)
                .font(.subheadline)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(status.color.opacity(0.18))
        )
        .accessibilityLabel("\(name) \(status.label)")
    }
}

struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    init(alignment: HorizontalAlignment = .leading, horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let addSpacing = currentRowWidth == 0 ? 0 : horizontalSpacing
            if currentRowWidth + addSpacing + size.width > maxWidth {
                // commit row
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                totalHeight += (totalHeight == 0 ? 0 : verticalSpacing) + currentRowHeight
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth += addSpacing + size.width
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        // commit last row
        maxRowWidth = max(maxRowWidth, currentRowWidth)
        totalHeight += currentRowHeight

        return CGSize(width: maxRowWidth.isFinite ? maxRowWidth : 0, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let addSpacing = (x == bounds.minX) ? 0 : horizontalSpacing
            if x + addSpacing + size.width > bounds.maxX {
                // wrap to next line
                x = bounds.minX
                y += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            }

            if x != bounds.minX { x += horizontalSpacing }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

extension MetricIcon {
    /// Returns an asset or SF Symbol name suitable for Image(_:) based on the icon value.
    var assetName: String? {
        // Prefer RawRepresentable<String> raw value if available using helper
        if let raw = stringRawValue(self) {
            return raw
        }
        // Next, use CustomStringConvertible description if meaningful
        if let describable = self as? CustomStringConvertible {
            let desc = describable.description
            return desc.isEmpty ? nil : desc
        }
        // Fallback: best-effort description, but ignore meaningless defaults
        let fallback = String(describing: self)
        return fallback.isEmpty || fallback == "(unknown)" ? nil : fallback
    }
}

#Preview {
    ContentView()
}


#Preview {
    NavigationStack {
        ContentView()
    }
}


