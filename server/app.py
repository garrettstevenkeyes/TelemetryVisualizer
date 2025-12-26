from __future__ import annotations

import sqlite3
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from db import connect, apply_migrations
from seed import seed
from simulator import TelemetrySimulator
from models import Machine, Metric, LatestReading, ReadingPoint

app = FastAPI(title="Telemetry Server", version="0.1.0")

# (Optional) If you ever run a web UI on a different port, CORS helps.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # for local dev
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_conn: sqlite3.Connection | None = None
_sim: TelemetrySimulator | None = None


@app.on_event("startup")
def on_startup() -> None:
    global _conn, _sim
    _conn = connect()
    apply_migrations(_conn)
    seed(_conn)
    _sim = TelemetrySimulator(_conn)


def conn() -> sqlite3.Connection:
    if _conn is None:
        raise RuntimeError("DB not initialized")
    return _conn


def sim() -> TelemetrySimulator:
    if _sim is None:
        raise RuntimeError("Simulator not initialized")
    return _sim


@app.get("/machines", response_model=list[Machine])
def get_machines() -> list[Machine]:
    rows = conn().execute(
        "SELECT machine_id, name, location, status FROM machines ORDER BY machine_id"
    ).fetchall()
    return [Machine(**dict(r)) for r in rows]


@app.get("/metrics", response_model=list[Metric])
def get_metrics() -> list[Metric]:
    rows = conn().execute(
        "SELECT metric_key, display_name, unit FROM metrics ORDER BY metric_key"
    ).fetchall()
    return [Metric(**dict(r)) for r in rows]


@app.get("/latest", response_model=list[LatestReading])
def get_latest(
    machine_id: str = Query(..., description="e.g. m-001")
) -> list[LatestReading]:
    # Verify machine exists (nice error)
    exists = conn().execute(
        "SELECT 1 FROM machines WHERE machine_id = ?",
        (machine_id,),
    ).fetchone()
    if not exists:
        raise HTTPException(status_code=404, detail="Unknown machine_id")

    rows = conn().execute(
        """
        SELECT machine_id, metric_key, ts_ms, value
        FROM latest_readings
        WHERE machine_id = ?
        ORDER BY metric_key
        """,
        (machine_id,),
    ).fetchall()
    return [LatestReading(**dict(r)) for r in rows]


@app.get("/history", response_model=list[ReadingPoint])
def get_history(
    machine_id: str = Query(...),
    metric_key: str = Query(...),
    start_ms: int | None = Query(None, description="epoch ms"),
    end_ms: int | None = Query(None, description="epoch ms"),
    limit: int = Query(500, ge=1, le=5000),
) -> list[ReadingPoint]:
    params: list[object] = [machine_id, metric_key]

    where = "WHERE machine_id = ? AND metric_key = ?"
    if start_ms is not None:
        where += " AND ts_ms >= ?"
        params.append(start_ms)
    if end_ms is not None:
        where += " AND ts_ms <= ?"
        params.append(end_ms)

    rows = conn().execute(
        f"""
        SELECT ts_ms, value
        FROM readings
        {where}
        ORDER BY ts_ms DESC
        LIMIT ?
        """,
        (*params, limit),
    ).fetchall()

    # Return ascending for charting convenience
    points = [ReadingPoint(**dict(r)) for r in rows]
    points.reverse()
    return points


@app.post("/simulate/start")
def simulate_start() -> dict:
    sim().start()
    return {"running": sim().is_running()}


@app.post("/simulate/stop")
def simulate_stop() -> dict:
    sim().stop()
    return {"running": sim().is_running()}


@app.get("/simulate/status")
def simulate_status() -> dict:
    return {"running": sim().is_running()}
