from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

import allin1


@dataclass(frozen=True)
class ApiError(Exception):
  status_code: int
  code: str
  message: str


def get_available_models() -> list[str]:
  return ["harmonix-all"] + [f"harmonix-fold{i}" for i in range(8)]

def process_audio_file(
  file_path: Path,
  *,
  model_name: str,
  device: str,
  demix_dir: Path,
  spec_dir: Path,
) -> dict:
  start = time.perf_counter()
  try:
    result = allin1.analyze(
      paths=str(file_path),
      model=model_name,
      device=device,
      keep_byproducts=False,
      demix_dir=str(demix_dir),
      spec_dir=str(spec_dir),
      multiprocess=False,
    )
  except AssertionError as e:
    raise ApiError(status_code=400, code="INVALID_MODEL", message=str(e)) from e
  except Exception as e:
    raise ApiError(status_code=500, code="PROCESSING_ERROR", message="Analysis failed") from e

  data = {
    "path": result.path.name,
    "bpm": int(result.bpm),
    "beats": [float(x) for x in result.beats],
    "downbeats": [float(x) for x in result.downbeats],
    "beat_positions": [int(x) for x in result.beat_positions],
    "segments": [{"start": float(s.start), "end": float(s.end), "label": str(s.label)} for s in result.segments],
  }
  return {"data": data, "processing_time": time.perf_counter() - start}
