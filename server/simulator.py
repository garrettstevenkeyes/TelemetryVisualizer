from __future__ import annotations

import math
import random
import threading
import time
import sqlite3


class TelemetrySimulator:
    def __init__(self, conn: sqlite3.Connection):
        self._conn = conn
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()
        self._lock = threading.Lock()
        self._running = False

        # configurable
        self.interval_s = 0.5  # how often to emit telemetry

    def is_running(self) -> bool:
        with self._lock:
            return self._running

    def start(self) -> None:
        with self._lock:
            if self._running:
                return
            self._running = True
            self._stop.clear()
            self._thread = threading.Thread(target=self._run_loop, daemon=True)
            self._thread.start()

    def stop(self) -> None:
        with self._lock:
            if not self._running:
                return
            self._running = False
            self._stop.set()

        if self._thread:
            self._thread.join(timeout=2.0)

    def _run_loop(self) -> None:
        machines = [row["machine_id"] for row in self._conn.execute("SELECT machine_id FROM machines")]
        metrics = [row["metric_key"] for row in self._conn.execute("SELECT metric_key FROM metrics")]

        # Phase offsets so machines aren't identical
        machine_phase = {m: random.random() * 10.0 for m in machines}
        metric_phase = {k: random.random() * 10.0 for k in metrics}

        while not self._stop.is_set():
            now_ms = int(time.time() * 1000)
            t = time.time()

            rows: list[tuple[str, str, int, float]] = []
            for m in machines:
                mp = machine_phase[m]
                for k in metrics:
                    kp = metric_phase[k]
                    value = self._value_for(k, t, mp, kp)
                    rows.append((m, k, now_ms, float(value)))

            # One transaction per tick
            with self._conn:
                self._conn.executemany(
                    "INSERT OR IGNORE INTO readings(machine_id, metric_key, ts_ms, value) VALUES (?,?,?,?)",
                    rows,
                )

            time.sleep(self.interval_s)

    def _value_for(self, metric_key: str, t: float, mp: float, kp: float) -> float:
        # Smooth wave + noise. Tune ranges per metric.
        noise = random.uniform(-0.5, 0.5)

        if metric_key == "temperature":
            base = 70.0 + 5.0 * math.sin((t / 6.0) + mp + kp)
            return base + noise
        if metric_key == "pressure":
            base = 101.3 + 2.0 * math.sin((t / 4.0) + mp * 0.7 + kp)
            return base + noise * 0.3
        if metric_key == "vibration":
            base = 3.0 + 1.5 * abs(math.sin((t / 2.0) + mp + kp))
            return base + noise * 0.2

        # Default generic metric
        return 10.0 + math.sin(t + mp + kp) + noise
