//
//  MetricView.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/29/25.
//

import SwiftUI
import Charts
import Combine
import Foundation

struct MetricView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MetricViewModel

    init(metric: Metric) {
        self.metric = metric
        _viewModel = StateObject(wrappedValue: MetricViewModel(metric: metric))
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Title
                    Text(metric.metricName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.eggshell)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Global legend under title
                    HStack(spacing: 18) {
                        LegendDot(color: MetricStatus.normal.color, label: "Good")
                        LegendDot(color: MetricStatus.warning.color, label: "Okay")
                        LegendDot(color: MetricStatus.alert.color, label: "Bad")
                        Spacer()
                    }
                    .padding(.top, 2)
                    .padding(.horizontal, 6)

                    // Chart with background bands
                    ZStack {
                        Chart {
                            ForEach(viewModel.readings) { reading in
                                LineMark(
                                    x: .value("Time", reading.timestamp),
                                    y: .value("Value", reading.value)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.eggshell)
                            }
                        }
                        .chartBackground { proxy in
                            MetricBandsBackground(
                                proxy: proxy,
                                goodMin: viewModel.goodMin,
                                goodMax: viewModel.goodMax,
                                okayMin: viewModel.okayMin,
                                okayMax: viewModel.okayMax,
                                badMin: viewModel.badMin,
                                badMax: viewModel.badMax,
                                goodFill: viewModel.goodFill,
                                okayFill: viewModel.okayFill,
                                badFill: viewModel.badFill,
                                openEndedGood: metric.metricGoodRangeMax < metric.metricGoodRangeMin,
                                openEndedBad: metric.metricBadRangeMin > metric.metricBadRangeMax
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.hour().minute().second())
                            }
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .chartYScale(domain: viewModel.suggestedYDomain())
                        .frame(height: 220)
                        .opacity(viewModel.hasData ? 1.0 : 0.3)

                        if !viewModel.hasData && !viewModel.isLoading {
                            Text("No Data")
                                .font(.headline)
                                .foregroundStyle(Color.eggshell.opacity(0.6))
                        }

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(Color.eggshell)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.22))
                    )
                    .squiggleCardBorder()

                    // Zone Distribution
                    ZStack {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Zone Distribution")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.eggshell)

                            HStack(alignment: .center, spacing: 12) {
                                // Percent list
                                VStack(alignment: .leading, spacing: 8) {
                                    LegendDot(color: MetricStatus.normal.color, label: "\(viewModel.goodPercentage())% Good")
                                    LegendDot(color: MetricStatus.warning.color, label: "\(viewModel.okayPercentage())% Okay")
                                    LegendDot(color: MetricStatus.alert.color, label: "\(viewModel.badPercentage())% Bad")
                                }

                                Spacer(minLength: 12)

                                // Pie chart (driven by percentages to match labels; omit zero-percent slices)
                                let goodP = viewModel.goodPercentage()
                                let okayP = viewModel.okayPercentage()
                                let badP = viewModel.badPercentage()

                                Chart {
                                    if goodP > 0 {
                                        SectorMark(
                                            angle: .value("Percent", goodP),
                                            innerRadius: .ratio(0.6)
                                        )
                                        .foregroundStyle(MetricStatus.normal.color)
                                    }

                                    if okayP > 0 {
                                        SectorMark(
                                            angle: .value("Percent", okayP),
                                            innerRadius: .ratio(0.6)
                                        )
                                        .foregroundStyle(MetricStatus.warning.color)
                                    }

                                    if badP > 0 {
                                        SectorMark(
                                            angle: .value("Percent", badP),
                                            innerRadius: .ratio(0.6)
                                        )
                                        .foregroundStyle(MetricStatus.alert.color)
                                    }
                                }
                                .chartLegend(.hidden)
                                .frame(width: 140, height: 140)
                            }
                        }
                        .opacity(viewModel.hasData ? 1.0 : 0.3)

                        if !viewModel.hasData && !viewModel.isLoading {
                            Text("No Data")
                                .font(.headline)
                                .foregroundStyle(Color.eggshell.opacity(0.6))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.22))
                    )
                    .squiggleCardBorder()

                    // Summary stats
                    ZStack {
                        VStack(alignment: .leading, spacing: 10) {
                            StatRow(label: "Current:", value: viewModel.formattedValue(viewModel.currentReading()))
                            StatRow(label: "Max:", value: viewModel.formattedValue(viewModel.maxReading()))
                            StatRow(label: "Min:", value: viewModel.formattedValue(viewModel.minReading()))
                            StatRow(label: "Average:", value: viewModel.formattedValue(viewModel.averageReading()))
                        }
                        .opacity(viewModel.hasData ? 1.0 : 0.3)

                        if !viewModel.hasData && !viewModel.isLoading {
                            Text("No Data")
                                .font(.headline)
                                .foregroundStyle(Color.eggshell.opacity(0.6))
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.22))
                    )
                    .squiggleCardBorder()

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.stopAll()
        }
        .onChange(of: metric.isActive) { _, isActive in
            viewModel.handleActiveChange(isActive)
        }
    }
}

private struct MetricBandsBackground: View {
    let proxy: ChartProxy
    let goodMin: Double
    let goodMax: Double
    let okayMin: Double
    let okayMax: Double
    let badMin: Double
    let badMax: Double
    let goodFill: Color
    let okayFill: Color
    let badFill: Color
    let openEndedGood: Bool
    let openEndedBad: Bool

    // Helpers moved out of the ViewBuilder to avoid declaration errors inside result builders
    private func yPos(_ y: Double, in plotFrame: CGRect) -> CGFloat? {
        // Reject non-finite input values
        guard y.isFinite else { return nil }
        // Obtain local Y from the chart proxy and ensure it's finite
        guard let localY = proxy.position(forY: y), localY.isFinite else { return nil }
        let absoluteY = localY + plotFrame.minY
        // Ensure the final value is finite
        guard absoluteY.isFinite else { return nil }
        // Clamp to the plot frame bounds to avoid out-of-bounds rendering leading to invalid sizes
        return min(max(absoluteY, plotFrame.minY), plotFrame.maxY)
    }

    @ViewBuilder
    private func bandView(yTop: CGFloat?, yBottom: CGFloat?, color: Color, plotFrame: CGRect) -> some View {
        // Resolve top and bottom, defaulting to plot frame edges if nil
        let topVal = yTop ?? plotFrame.minY
        let bottomVal = yBottom ?? plotFrame.maxY

        // Compute height and validate dimensions
        let rawHeight = abs(bottomVal - topVal)
        let height = rawHeight.isFinite ? rawHeight : 0
        let width = plotFrame.width.isFinite ? plotFrame.width : 0

        if width > 0 && height > 0 {
            let minY = min(topVal, bottomVal)
            Rectangle()
                .fill(color)
                .frame(width: width, height: height)
                .position(x: plotFrame.midX, y: minY + height / 2)
        } else {
            EmptyView()
        }
    }

    var body: some View {
        GeometryReader { geo in
            if let plotAnchor = proxy.plotFrame {
                let plotFrame = geo[plotAnchor]

                // Validate plot frame dimensions before drawing any bands
                if plotFrame.width.isFinite && plotFrame.height.isFinite && plotFrame.width > 0 && plotFrame.height > 0 {
                    Group {
                        // GOOD band: closed [goodMin, goodMax] or open-ended (>= goodMin)
                        if let yGoodMin = yPos(goodMin, in: plotFrame) {
                            if openEndedGood {
                                bandView(yTop: nil, yBottom: yGoodMin, color: goodFill, plotFrame: plotFrame)
                            } else {
                                let yGoodMax = yPos(goodMax, in: plotFrame)
                                bandView(yTop: yGoodMax, yBottom: yGoodMin, color: goodFill, plotFrame: plotFrame)
                            }
                        }

                        // OKAY band: only if valid closed interval
                        if okayMin <= okayMax, let yOkayMin = yPos(okayMin, in: plotFrame), let yOkayMax = yPos(okayMax, in: plotFrame) {
                            bandView(yTop: yOkayMax, yBottom: yOkayMin, color: okayFill, plotFrame: plotFrame)
                        }

                        // BAD band: closed [badMin, badMax] or open-ended (<= badMax)
                        if openEndedBad {
                            if let yBadMax = yPos(badMax, in: plotFrame) {
                                bandView(yTop: nil, yBottom: yBadMax, color: badFill, plotFrame: plotFrame)
                            }
                        } else if let yBadMin = yPos(badMin, in: plotFrame), let yBadMax = yPos(badMax, in: plotFrame) {
                            bandView(yTop: yBadMin, yBottom: yBadMax, color: badFill, plotFrame: plotFrame)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Streaming support and helpers

struct MetricReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

struct ZoneDistribution: Codable {
    let good: Int
    let okay: Int
    let bad: Int
    let windowSeconds: Int?
}

@MainActor
final class MetricStream: ObservableObject {
    @Published private(set) var readings: [MetricReading] = []
    @Published private(set) var serverDistribution: ZoneDistribution?
    @Published private(set) var hasData: Bool = false
    @Published private(set) var isLoading: Bool = true

    private var timer: Timer?
    private var startDate: Date = Date()
    private var pollingTask: Task<Void, Never>?

    // Backend connection info
    private var machineId: String?
    private var metricKey: String?

    /// Configure backend connection for real data fetching
    func configure(machineId: String?, metricKey: String?) {
        self.machineId = machineId
        self.metricKey = metricKey
    }

    func start() {
        stop()
        isLoading = true
        hasData = false

        // Use simulation in preview mode or if backend info not configured
        if TelemetryAPIConfig.isPreview || machineId == nil || metricKey == nil {
            startSimulation()
        } else {
            startBackendPolling()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Simulation Mode (for previews)

    private func startSimulation() {
        startDate = Date()
        isLoading = false
        hasData = true  // Simulation always has data
        let capturedStartDate = startDate
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let t = Date()
            let i = t.timeIntervalSince(capturedStartDate)
            // Simulated reading
            let simulated = 70.0 + sin(i / 3.0) * 15.0 + Double.random(in: -2...2)
            Task { @MainActor in
                self.append(timestamp: t, value: simulated)
            }
        }
    }

    // MARK: - Backend Polling Mode

    private func startBackendPolling() {
        guard let machineId = machineId, let metricKey = metricKey else { return }

        // First, fetch historical data
        Task {
            await fetchHistory(machineId: machineId, metricKey: metricKey)
        }

        // Then start polling for latest readings
        pollingTask = Task { [weak self] in
            await self?.pollLatestReadings(machineId: machineId, metricKey: metricKey)
        }
    }

    private func fetchHistory(machineId: String, metricKey: String) async {
        do {
            let history = try await TelemetryAPI.shared.fetchHistory(
                machineId: machineId,
                metricKey: metricKey,
                limit: 500
            )

            let newReadings = history.map { point in
                MetricReading(timestamp: point.timestamp, value: point.value)
            }

            self.readings = newReadings
            self.hasData = !newReadings.isEmpty
            self.isLoading = false
        } catch {
            // History fetch failed - will rely on polling for live data
            print("Failed to fetch history: \(error)")
            self.isLoading = false
        }
    }

    private func pollLatestReadings(machineId: String, metricKey: String) async {
        while !Task.isCancelled {
            do {
                let latestReadings = try await TelemetryAPI.shared.fetchLatestReadings(machineId: machineId)

                // Find the reading for our metric
                if let reading = latestReadings.first(where: { $0.metricKey == metricKey }) {
                    self.append(timestamp: reading.timestamp, value: reading.value)
                    if !self.hasData {
                        self.hasData = true
                    }
                }
            } catch {
                // Polling error - will retry
                print("Polling error: \(error)")
            }

            // Poll every 1 second
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    func startAggregatesLongPolling(metricID: UUID) {
        // Zone distribution is computed client-side from readings
        // No server endpoint needed for this
    }

    func stopAggregatesLongPolling() {
        // No-op since we compute distribution client-side
    }

    private func append(timestamp: Date, value: Double) {
        // Avoid duplicate timestamps
        if let last = readings.last, last.timestamp >= timestamp {
            return
        }
        readings.append(MetricReading(timestamp: timestamp, value: value))
        if readings.count > 600 { readings.removeFirst(readings.count - 600) }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundStyle(Color.eggshell)
            HorizontalDashedLine()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .foregroundStyle(Color.eggshell.opacity(0.6))
                .frame(maxWidth: .infinity, maxHeight: 1)
            Text(value)
                .foregroundStyle(Color.eggshell)
        }
        .font(.body)
    }
}

private struct HorizontalDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return p
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.footnote)
                .foregroundStyle(Color.eggshell)
        }
    }
}

#Preview {
    let sample = Metric(
        id: UUID(),
        metricName: "Temperature",
        metricIcon: .thermometer,
        metricUnit: "ºC",
        metricGoodRangeMin: 65,
        metricGoodRangeMax: 85, // set < min to preview open-ended good
        metricOkayRangeMin: 55,
        metricOkayRangeMax: 64,
        metricBadRangeMin: 0,   // set > max to preview open-ended bad
        metricBadRangeMax: 54,
        metricZonePercentGood: 0,
        metricZonePercentOkay: 0,
        metricZonePercentBad: 0,
        isActive: true,
        metricValue: 72
    )
    NavigationStack { MetricView(metric: sample) }
}

