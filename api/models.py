from __future__ import annotations

from pydantic import BaseModel


class ErrorData(BaseModel):
  code: str
  message: str


class ErrorResponse(BaseModel):
  success: bool = False
  error: ErrorData


class SegmentData(BaseModel):
  start: float
  end: float
  label: str


class AnalysisData(BaseModel):
  path: str
  bpm: int
  beats: list[float]
  downbeats: list[float]
  beat_positions: list[int]
  segments: list[SegmentData]


class AnalysisResponse(BaseModel):
  success: bool = True
  data: AnalysisData
  processing_time: float


class HealthResponse(BaseModel):
  status: str
  gpu_available: bool
  device: str


class ModelsResponse(BaseModel):
  models: list[str]

