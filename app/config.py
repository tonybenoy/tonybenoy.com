"""Configuration management for the application."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8"
    )

    # Application settings
    app_name: str = "TonyBenoy.com"
    debug: bool = False

    # GitHub API settings
    github_username: str = "tonybenoy"
    github_token: str | None = None
    github_api_timeout: float = 30.0

    # Redis settings
    redis_host: str = "redis_db"
    redis_port: int = 6379
    redis_db: int = 0
    redis_password: str | None = None
    redis_cache_ttl: int = 3600  # 1 hour

    # Security settings
    allowed_hosts: list[str] = ["*"]
    cors_origins: list[str] = ["*"]

    # Logging settings
    log_level: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
