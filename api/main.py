from __future__ import annotations

import asyncio
import tempfile
from pathlib import Path

from anyio import to_thread
from fastapi import Depends, FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse

from .auth import verify_api_key
from .config import settings
from .handlers import ApiError, get_available_models, process_audio_file
from .models import AnalysisResponse, HealthResponse, ModelsResponse

app = FastAPI(title="Music Analysis API")
_max_concurrent_requests = max(1, settings.max_concurrent_requests)
_inflight_lock = asyncio.Lock()
_inflight_requests = 0


async def _try_acquire_concurrency_slot() -> bool:
  global _inflight_requests
  async with _inflight_lock:
    if _inflight_requests >= _max_concurrent_requests:
      return False
    _inflight_requests += 1
    return True


async def _release_concurrency_slot() -> None:
  global _inflight_requests
  async with _inflight_lock:
    _inflight_requests = max(0, _inflight_requests - 1)


def _error(status_code: int, code: str, message: str) -> JSONResponse:
  return JSONResponse(status_code=status_code, content={"success": False, "error": {"code": code, "message": message}})


@app.exception_handler(ApiError)
async def _api_error_handler(_request, exc: ApiError):
  return _error(exc.status_code, exc.code, exc.message)


@app.get("/health", response_model=HealthResponse)
async def health():
  try:
    import torch

    gpu = bool(torch.cuda.is_available())
    device = "cuda" if gpu else "cpu"
  except Exception:
    gpu = False
    device = "unknown"
  return {"status": "ok", "gpu_available": gpu, "device": device}


@app.get("/models", response_model=ModelsResponse)
async def models():
  return {"models": get_available_models()}


async def _save_upload_to_path(upload: UploadFile, dst: Path) -> int:
  max_size = settings.max_file_size_bytes
  written = 0
  chunk_size = 1024 * 1024
  with open(dst, "wb") as f:
    while True:
      chunk = await upload.read(chunk_size)
      if not chunk:
        break
      written += len(chunk)
      if written > max_size:
        raise ApiError(status_code=413, code="FILE_TOO_LARGE", message=f"Max size is {max_size} bytes")
      f.write(chunk)
  return written


@app.post("/analyze", response_model=AnalysisResponse)
async def analyze_audio(
  file: UploadFile = File(...),
  model: str = Form(default="harmonix-all"),
  _api_key: str = Depends(verify_api_key),
):
  acquired = False
  try:
    acquired = await _try_acquire_concurrency_slot()
    if not acquired:
      raise ApiError(status_code=429, code="TOO_MANY_REQUESTS", message="Too many concurrent requests")

    filename = Path(file.filename or "upload").name
    if not filename:
      filename = "upload"

    suffix = Path(filename).suffix.lower()
    if suffix not in settings.allowed_extensions:
      raise ApiError(status_code=400, code="INVALID_FILE_FORMAT", message="Only .mp3/.wav are supported")

    with tempfile.TemporaryDirectory() as tmp_dir:
      tmp_path = Path(tmp_dir)
      audio_path = tmp_path / filename
      await _save_upload_to_path(file, audio_path)

      try:
        import torch

        device = "cuda" if torch.cuda.is_available() else "cpu"
      except Exception:
        device = "cpu"
      demix_dir = tmp_path / "demix"
      spec_dir = tmp_path / "spec"

      try:
        result = await asyncio.wait_for(
          to_thread.run_sync(
            process_audio_file,
            audio_path,
            model_name=model,
            device=device,
            demix_dir=demix_dir,
            spec_dir=spec_dir,
          ),
          timeout=settings.analysis_timeout_seconds,
        )
      except TimeoutError as e:
        raise ApiError(status_code=500, code="PROCESSING_ERROR", message="Analysis timeout") from e

      return {"success": True, "data": result["data"], "processing_time": result["processing_time"]}
  finally:
    if acquired:
      await _release_concurrency_slot()
