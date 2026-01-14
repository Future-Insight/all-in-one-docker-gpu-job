from __future__ import annotations

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
  model_config = SettingsConfigDict(env_file=".env", extra="ignore")

  api_keys: list[str] = Field(default_factory=list, validation_alias="API_KEYS")
  max_file_size_bytes: int = Field(default=100 * 1024 * 1024, validation_alias="MAX_FILE_SIZE_BYTES")
  max_concurrent_requests: int = Field(default=2, validation_alias="MAX_CONCURRENT_REQUESTS")
  analysis_timeout_seconds: int = Field(default=120, validation_alias="ANALYSIS_TIMEOUT_SECONDS")
  allowed_extensions: set[str] = Field(default_factory=lambda: {".mp3", ".wav"})

  @field_validator("api_keys", mode="before")
  @classmethod
  def _parse_api_keys(cls, value):
    if value is None:
      return []
    if isinstance(value, (list, tuple, set)):
      return [str(v).strip() for v in value if str(v).strip()]
    if isinstance(value, str):
      return [part.strip() for part in value.split(",") if part.strip()]
    return []


settings = Settings()
