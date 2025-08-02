"""Configuration management for the application."""

import json
from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Application settings
    app_name: str = "TonyBenoy.com"
    debug: bool = False

    # GitHub API settings
    github_username: str = "tonybenoy"
    github_token: str | None = None
    github_api_timeout: float = 30.0

    # Cache settings
    cache_ttl: int = 3600  # 1 hour

    # Security settings
    allowed_hosts: list[str] = ["*"]
    cors_origins: list[str] = ["*"]

    # Logging settings
    log_level: str = "INFO"
    
    # Email/SMTP settings (optional)
    smtp_server: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    contact_email: str = "me@tonybenoy.com"

    @field_validator("allowed_hosts", "cors_origins", mode="before")
    @classmethod
    def parse_json_list(cls, v):
        """Parse JSON string list from environment variables."""
        if isinstance(v, str):
            try:
                return json.loads(v)
            except json.JSONDecodeError:
                # If not valid JSON, split by comma and strip whitespace
                return [item.strip().strip('"') for item in v.split(",")]
        return v


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
