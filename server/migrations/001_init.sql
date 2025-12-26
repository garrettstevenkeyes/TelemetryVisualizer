PRAGMA foreign_keys = ON;

-- Create table to hold the machines
-- # I may add more complicated location information later with a location type
CREATE TABLE IF NOT EXISTS machines (
  machine_id     TEXT PRIMARY KEY,
  name           TEXT NOT NULL,
  location       TEXT,
  status         TEXT NOT NULL DEFAULT 'ok',
  created_at     TEXT NOT NULL
    DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Create table to store metric types
CREATE TABLE IF NOT EXISTS metrics (
  metric_key     TEXT PRIMARY KEY,
  display_name   TEXT NOT NULL,
  unit           TEXT NOT NULL,
  created_at     TEXT NOT NULL
    DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Create table for storing individual metrics 
-- Each reading has unique pairings of (machine_id, metric_key, ts_ms)
CREATE TABLE IF NOT EXISTS readings (
  machine_id     TEXT NOT NULL,
  metric_key     TEXT NOT NULL,
  ts_ms          INTEGER NOT NULL,
  value          REAL NOT NULL,

  PRIMARY KEY (machine_id, metric_key, ts_ms),

  FOREIGN KEY (machine_id) REFERENCES machines(machine_id) ON DELETE CASCADE,
  FOREIGN KEY (metric_key) REFERENCES metrics(metric_key) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_readings_machine_metric_ts
ON readings(machine_id, metric_key, ts_ms DESC);

-- Latest readings table for quick retrieval
CREATE TABLE IF NOT EXISTS latest_readings (
  machine_id   TEXT NOT NULL,
  metric_key   TEXT NOT NULL,
  ts_ms        INTEGER NOT NULL,
  value        REAL NOT NULL,

  PRIMARY KEY (machine_id, metric_key),

  FOREIGN KEY (machine_id) REFERENCES machines(machine_id) ON DELETE CASCADE,
  FOREIGN KEY (metric_key) REFERENCES metrics(metric_key) ON DELETE CASCADE
);

-- Update the latest table with the latest readings
CREATE TRIGGER IF NOT EXISTS trg_readings_upsert_latest
AFTER INSERT ON readings
BEGIN
  INSERT INTO latest_readings(machine_id, metric_key, ts_ms, value)
  VALUES (NEW.machine_id, NEW.metric_key, NEW.ts_ms, NEW.value)
  ON CONFLICT(machine_id, metric_key) DO UPDATE SET
    ts_ms = CASE
      WHEN excluded.ts_ms > latest_readings.ts_ms THEN excluded.ts_ms
      ELSE latest_readings.ts_ms
    END,
    value = CASE
      WHEN excluded.ts_ms > latest_readings.ts_ms THEN excluded.value
      ELSE latest_readings.value
    END;
END;