//
//  Metric.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/30/25.
//

import Foundation

struct Metric: Codable, Identifiable {
    let id: UUID
    let metricName: String
    let metricIcon: MetricIcon
    let metricUnit: String
    let metricGoodRangeMin: Double
    let metricGoodRangeMax: Double
    let metricOkayRangeMin: Double
    let metricOkayRangeMax: Double
    let metricBadRangeMin: Double
    let metricBadRangeMax: Double
    let metricZonePercentGood: Double
    let metricZonePercentOkay: Double
    let metricZonePercentBad: Double
    var metricValue: Double
}

enum MetricIcon: String, Codable {
    case gauge = "Gauge"
    case thermometer = "Thermometer"
    case vibration = "Vibration"
}
