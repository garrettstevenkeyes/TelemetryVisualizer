//
//  Metric.swift
//  TelemetryPipeline
//
//  Created by Garrett Keyes on 12/30/25.
//

import Foundation
import SwiftUI

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
    var isActive: Bool
    var metricValue: Double
}

enum MetricIcon: String, Codable {
    case gauge = "Guage"
    case thermometer = "Thermometer"
    case vibration = "Vibration"
}

enum MetricStatus {
    case normal
    case warning
    case alert
    case inactive

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .alert: return "Alert"
        case .inactive: return "Inactive"
        }
    }

    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .yellow
        case .alert: return .red
        case .inactive: return .gray
        }
    }

    var symbolName: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .alert: return "xmark.octagon.fill"
        case .inactive: return "pause.circle.fill"
        }
    }
}
