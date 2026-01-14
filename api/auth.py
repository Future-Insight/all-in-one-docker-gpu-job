from __future__ import annotations

from fastapi import Security
from fastapi.security import APIKeyHeader

from .config import settings
from .handlers import ApiError


api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


async def verify_api_key(api_key: str | None = Security(api_key_header)) -> str:
  if not api_key or api_key not in settings.api_keys:
    raise ApiError(status_code=401, code="UNAUTHORIZED", message="Invalid API Key")
  return api_key
