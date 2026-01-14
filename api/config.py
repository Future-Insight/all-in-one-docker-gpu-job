from __future__ import annotations

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
  # 对 list/dict 等“复杂类型”默认会尝试按 JSON 解码；但 API_KEYS 更常见的是 "k1,k2" 形式。
  # 关闭自动 JSON 解码，交给下面的 validator 统一兼容处理（也兼容传入 JSON 数组字符串）。
  model_config = SettingsConfigDict(env_file=".env", extra="ignore", enable_decoding=False)

  api_keys: list[str] = Field(default_factory=list, validation_alias="API_KEYS")
  max_file_size_bytes: int = Field(default=100 * 1024 * 1024, validation_alias="MAX_FILE_SIZE_BYTES")
  max_concurrent_requests: int = Field(default=5, validation_alias="MAX_CONCURRENT_REQUESTS")
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
      s = value.strip()
      if not s:
        return []
      if s.startswith("["):
        try:
          import json

          parsed = json.loads(s)
          if isinstance(parsed, list):
            return [str(v).strip() for v in parsed if str(v).strip()]
        except Exception:
          pass
      return [part.strip() for part in s.split(",") if part.strip()]
    return []


settings = Settings()
