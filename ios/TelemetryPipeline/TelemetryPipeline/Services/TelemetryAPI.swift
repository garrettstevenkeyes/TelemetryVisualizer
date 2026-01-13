//
//  TelemetryAPI.swift
//  TelemetryPipeline
//
//  API client for the Python telemetry backend service.
//

import Foundation

// MARK: - Configuration

enum TelemetryAPIConfig {
    /// Base URL for the telemetry service.
    /// - Simulator: Use localhost
    /// - Physical device: Use your Mac's LAN IP (e.g., "http://192.168.1.100:8000")
    #if targetEnvironment(simulator)
    static let baseURL = "http://127.0.0.1:8000"
    #else
    static let baseURL = "http://127.0.0.1:8000" // Change to your Mac's LAN IP for physical device
    #endif

    /// Whether we're running in Xcode preview mode
    static let isPreview: Bool =
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

// MARK: - Backend Response Models

struct BackendMachine: Codable, Identifiable, Sendable {
    let machineId: String
    let name: String
    let location: String?
    let status: String

    var id: String { machineId }

    enum CodingKeys: String, CodingKey {
        case machineId = "machine_id"
        case name
        case location
        case status
    }
}

struct BackendMetric: Codable, Identifiable, Sendable {
    let metricKey: String
    let displayName: String
    let unit: String

    var id: String { metricKey }

    enum CodingKeys: String, CodingKey {
        case metricKey = "metric_key"
        case displayName = "display_name"
        case unit
    }
}

struct LatestReading: Codable, Sendable {
    let machineId: String
    let metricKey: String
    let tsMs: Int64
    let value: Double

    enum CodingKeys: String, CodingKey {
        case machineId = "machine_id"
        case metricKey = "metric_key"
        case tsMs = "ts_ms"
        case value
    }

    var timestamp: Date {
        Date(timeIntervalSince1970: Double(tsMs) / 1000.0)
    }
}

struct ReadingPoint: Codable, Sendable {
    let tsMs: Int64
    let value: Double

    enum CodingKeys: String, CodingKey {
        case tsMs = "ts_ms"
        case value
    }

    var timestamp: Date {
        Date(timeIntervalSince1970: Double(tsMs) / 1000.0)
    }
}

struct SimulatorStatus: Codable, Sendable {
    let running: Bool
}

// MARK: - API Errors

enum TelemetryAPIError: Error, LocalizedError, Sendable {
    case invalidURL
    case networkError(String)
    case decodingError(String)
    case httpError(statusCode: Int)
    case previewMode

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .previewMode:
            return "Running in preview mode"
        }
    }
}

// MARK: - API Client

actor TelemetryAPI {
    static let shared = TelemetryAPI()

    private let session: URLSession
    private let decoder: Foundation.JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.decoder = Foundation.JSONDecoder()
    }

    // MARK: - Machines

    func fetchMachines() async throws -> [BackendMachine] {
        guard await !TelemetryAPIConfig.isPreview else {
            throw TelemetryAPIError.previewMode
        }
        return try await get(endpoint: "/machines")
    }

    // MARK: - Metrics

    func fetchMetrics() async throws -> [BackendMetric] {
        guard await !TelemetryAPIConfig.isPreview else {
            throw TelemetryAPIError.previewMode
        }
        return try await get(endpoint: "/metrics")
    }

    // MARK: - Readings

    func fetchLatestReadings(machineId: String) async throws -> [LatestReading] {
        guard await !TelemetryAPIConfig.isPreview else {
            throw TelemetryAPIError.previewMode
        }
        return try await get(endpoint: "/latest?machine_id=\(machineId)")
    }

    func fetchHistory(
        machineId: String,
        metricKey: String,
        startMs: Int64? = nil,
        endMs: Int64? = nil,
        limit: Int = 500
    ) async throws -> [ReadingPoint] {
        guard await !TelemetryAPIConfig.isPreview else {
            throw TelemetryAPIError.previewMode
        }

        var endpoint = "/history?machine_id=\(machineId)&metric_key=\(metricKey)&limit=\(limit)"
        if let startMs = startMs {
            endpoint += "&start_ms=\(startMs)"
        }
        if let endMs = endMs {
            endpoint += "&end_ms=\(endMs)"
        }
        return try await get(endpoint: endpoint)
    }

    // MARK: - Simulator Control

    func startSimulator() async throws -> SimulatorStatus {
        guard await !TelemetryAPIConfig.isPreview else {
            throw TelemetryAPIError.previewMode
        }
        return try await post(endpoint: "/simulate/start")
    }

    func stopSimulator() async throws -> SimulatorStatus {
        guard await !TelemetryAPIConfig.isPreview else {
            throw TelemetryAPIError.previewMode
        }
        return try await post(endpoint: "/simulate/stop")
    }

    func fetchSimulatorStatus() async throws -> SimulatorStatus {
        guard await !TelemetryAPIConfig.isPreview else {
            throw TelemetryAPIError.previewMode
        }
        return try await get(endpoint: "/simulate/status")
    }

    // MARK: - HTTP Methods

    private func get<T: Swift.Decodable>(endpoint: String) async throws -> T {
        guard let url = await URL(string: TelemetryAPIConfig.baseURL + endpoint) else {
            throw TelemetryAPIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TelemetryAPIError.networkError("Bad server response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw TelemetryAPIError.httpError(statusCode: httpResponse.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw TelemetryAPIError.decodingError(error.localizedDescription)
            }
        } catch let error as TelemetryAPIError {
            throw error
        } catch {
            throw TelemetryAPIError.networkError(error.localizedDescription)
        }
    }

    private func post<T: Swift.Decodable>(endpoint: String) async throws -> T {
        guard let url = await URL(string: TelemetryAPIConfig.baseURL + endpoint) else {
            throw TelemetryAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TelemetryAPIError.networkError("Bad server response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw TelemetryAPIError.httpError(statusCode: httpResponse.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw TelemetryAPIError.decodingError(error.localizedDescription)
            }
        } catch let error as TelemetryAPIError {
            throw error
        } catch {
            throw TelemetryAPIError.networkError(error.localizedDescription)
        }
    }
}

