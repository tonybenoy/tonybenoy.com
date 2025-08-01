"""Configuration management for the application."""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application settings
    app_name: str = Field(default="TonyBenoy.com", env="APP_NAME")
    debug: bool = Field(default=False, env="DEBUG")

    # GitHub API settings
    github_username: str = Field(default="tonybenoy", env="GITHUB_USERNAME")
    github_token: str | None = Field(default=None, env="GITHUB_TOKEN")
    github_api_timeout: float = Field(default=30.0, env="GITHUB_API_TIMEOUT")

    # Redis settings
    redis_host: str = Field(default="redis_db", env="REDIS_HOST")
    redis_port: int = Field(default=6379, env="REDIS_PORT")
    redis_db: int = Field(default=0, env="REDIS_DB")
    redis_password: str | None = Field(default=None, env="REDIS_PASSWORD")
    redis_cache_ttl: int = Field(default=3600, env="REDIS_CACHE_TTL")  # 1 hour

    # Security settings
    allowed_hosts: list[str] = Field(default=["*"], env="ALLOWED_HOSTS")
    cors_origins: list[str] = Field(default=["*"], env="CORS_ORIGINS")

    # Logging settings
    log_level: str = Field(default="INFO", env="LOG_LEVEL")

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()
