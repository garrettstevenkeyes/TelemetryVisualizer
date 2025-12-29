# Telemetry App – Database & Service Overview (Local Dev)

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
