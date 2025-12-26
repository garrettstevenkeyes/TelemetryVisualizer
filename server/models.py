from pydantic import BaseModel


class Machine(BaseModel):
    machine_id: str
    name: str
    location: str | None = None
    status: str


class Metric(BaseModel):
    metric_key: str
    display_name: str
    unit: str


class LatestReading(BaseModel):
    machine_id: str
    metric_key: str
    ts_ms: int
    value: float


class ReadingPoint(BaseModel):
    ts_ms: int
    value: float
