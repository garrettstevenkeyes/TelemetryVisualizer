import sqlite3


def seed(conn: sqlite3.Connection) -> None:
    machines = [
        ("m-001", "Press 1", "Plant A", "ok"),
        ("m-002", "CNC 2", "Plant A", "ok"),
        ("m-003", "Oven 1", "Plant B", "ok"),
    ]

    metrics = [
        ("temperature", "Temperature", "C"),
        ("pressure", "Pressure", "kPa"),
        ("vibration", "Vibration", "mm/s"),
    ]

    with conn:
        conn.executemany(
            """
            INSERT OR IGNORE INTO machines(machine_id, name, location, status)
            VALUES (?, ?, ?, ?)
            """,
            machines,
        )
        conn.executemany(
            """
            INSERT OR IGNORE INTO metrics(metric_key, display_name, unit)
            VALUES (?, ?, ?)
            """,
            metrics,
        )
