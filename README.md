# TelemetryApp

A real-time telemetry monitoring system with a Python backend service and iOS application.

## Quick Start

### 1. Start the Python Backend

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

The server automatically initializes the database, seeds sample data, and starts the simulator.

### 2. Run the iOS App

**Simulator**: Open `ios/TelemetryPipeline/TelemetryPipeline.xcodeproj` in Xcode and run. Connects to `http://127.0.0.1:8000` automatically.

**Physical Device**: Update `TelemetryAPI.swift` with your Mac's LAN IP:
```swift
static let baseURL = "http://YOUR_MAC_IP:8000"
```

---

# Database & Service Overview (Local Dev)

## Database (SQLite)

### Tables

- **machines**  
  Catalog of machines/factories  
  Fields: `machine_id`, `name`, `location`, `status`, `created_at`

- **metrics**  
  Catalog of metric definitions  
  Fields: `metric_key`, `display_name`, `unit`, `created_at`

- **readings**  
  Time-series telemetry data  
  Fields: `machine_id`, `metric_key`, `ts_ms`, `value`  
  Primary Key: `(machine_id, metric_key, ts_ms)` (prevents duplicates)

- **latest_readings**  
  Cached latest value per machine + metric (for fast dashboards)  
  Fields: `machine_id`, `metric_key`, `ts_ms`, `value`

### Indexes & Triggers

- Index on `readings(machine_id, metric_key, ts_ms DESC)` for fast history queries
- Trigger on insert into `readings` keeps `latest_readings` updated  
  (only updates if the new timestamp is newer)

---

## Service (Python FastAPI)

### Responsibilities

- Initialize SQLite on startup
- Apply schema migrations
- Seed `machines` and `metrics`
- Run a background telemetry simulator
- Expose HTTP endpoints for the iOS app

### Core Endpoints

- `GET /machines`
- `GET /metrics`
- `GET /latest?machine_id=m-001`
- `GET /history?machine_id=m-001&metric_key=temperature&start_ms=&end_ms=&limit=`
- `POST /simulate/start`
- `POST /simulate/stop`
- `GET /simulate/status`

---

## Local Development Steps

### 1) Create virtual environment & install dependencies

```bash
cd telemetry/server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2) Run the server

uvicorn app:app --reload --host 0.0.0.0 --port 8000

### 3) Start the simulator

curl -X POST http://127.0.0.1:8000/simulate/start

### 4) Verify data is flowing

curl http://127.0.0.1:8000/machines
curl "http://127.0.0.1:8000/latest?machine_id=m-001"

### 5) Connect the iOS app

- iOS Simulator: http://127.0.0.1:8000
- Physical device: http://<your-mac-lan-ip>:8000 (same Wi-Fi)
- If HTTP is blocked, allow it via App Transport Security (dev only)


 
## iOS App

<table>
  <tr>
    <td align="center">
      <strong>Main metric page</strong><br>
      <img width="171" height="256" alt="DashboardMockup" src="https://github.com/user-attachments/assets/69153500-8042-4dd3-9b43-404d260c153d">
    </td>
    <td align="center">
      <strong>Drill-in metric page</strong><br>
      <img width="171" height="256" alt="DrillInMetricScreen" src="https://github.com/user-attachments/assets/594c9461-7d61-48e7-8e03-0f145ac1fa0f">
    </td>
    <td align="center">
      <strong>Add metric page</strong><br>
      <img width="171" height="256" alt="AddMetricScreen" src="https://github.com/user-attachments/assets/8545ddb2-f34b-40e4-892a-92a8634fa8bd">
    </td>
  </tr>
</table>

### Architecture

The iOS app follows **MVVM (Model-View-ViewModel)** architecture:

```
ios/TelemetryPipeline/TelemetryPipeline/
├── Models/             # Data models (Metric, MetricStatus)
├── Services/           # API client (TelemetryAPI)
├── MainScreen/         # Dashboard (ContentView + ContentViewModel)
├── MetricDrilldown/    # Detail view with charts (MetricView + MetricViewModel)
├── AddMetric/          # Metric creation form
└── BackgroundTheme/    # Custom styling (paper texture, squiggle borders)
```

### Data Flow

1. On launch, the app fetches machines and metrics from the backend
2. Latest readings are polled every 1 second for live updates
3. Metric detail views fetch historical data and display real-time charts
4. Zone distribution (Good/Okay/Bad) is calculated from readings

### Preview Mode

SwiftUI previews use local simulation - no backend required. The app detects preview mode and generates fake data automatically.

---

## Troubleshooting

**iOS app shows "Network error"**
- Ensure Python server is running
- Check firewall allows port 8000
- Physical devices must be on the same network

**No data in charts**
- Verify simulator: `curl http://localhost:8000/simulate/status`
- Start if stopped: `curl -X POST http://localhost:8000/simulate/start`



