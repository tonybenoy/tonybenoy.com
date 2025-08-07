from unittest.mock import patch

from app.config import Settings, get_settings


class TestSettings:
    """Test Settings configuration class."""

    def test_default_values(self):
        """Test default configuration values."""
        settings = Settings()

        assert settings.app_name == "TonyBenoy.com"
        assert settings.debug is False
        assert settings.github_username == "tonybenoy"
        assert settings.github_token is None
        assert settings.cache_ttl == 3600
        assert settings.allowed_hosts == ["*"]
        assert settings.cors_origins == ["*"]
        assert settings.log_level == "INFO"
        assert settings.contact_email == "me@tonybenoy.com"

    def test_parse_json_list_with_valid_json(self):
        """Test parsing valid JSON list from environment."""
        json_string = '["host1.com", "host2.com"]'
        result = Settings.parse_json_list(json_string)
        assert result == ["host1.com", "host2.com"]

    def test_parse_json_list_with_comma_separated(self):
        """Test parsing comma-separated string."""
        csv_string = 'host1.com, "host2.com", host3.com'
        result = Settings.parse_json_list(csv_string)
        assert result == ["host1.com", "host2.com", "host3.com"]

    def test_parse_json_list_with_invalid_json(self):
        """Test parsing invalid JSON falls back to comma-separated."""
        invalid_json = "host1.com, host2.com"
        result = Settings.parse_json_list(invalid_json)
        assert result == ["host1.com", "host2.com"]

    def test_parse_json_list_with_list_input(self):
        """Test that list input is returned as-is."""
        list_input = ["host1.com", "host2.com"]
        result = Settings.parse_json_list(list_input)
        assert result == ["host1.com", "host2.com"]

    @patch.dict(
        "os.environ",
        {
            "GITHUB_USERNAME": "testuser",
            "GITHUB_TOKEN": "test_token",
            "DEBUG": "true",
            "CACHE_TTL": "7200",
            "ALLOWED_HOSTS": '["localhost", "127.0.0.1"]',
            "LOG_LEVEL": "DEBUG",
        },
    )
    def test_settings_from_environment(self):
        """Test loading settings from environment variables."""
        settings = Settings()

        assert settings.github_username == "testuser"
        assert settings.github_token == "test_token"
        assert settings.debug is True
        assert settings.cache_ttl == 7200
        assert settings.allowed_hosts == ["localhost", "127.0.0.1"]
        assert settings.log_level == "DEBUG"

    def test_get_settings_caching(self):
        """Test that get_settings returns cached instance."""
        # Clear the cache first
        get_settings.cache_clear()

        settings1 = get_settings()
        settings2 = get_settings()

        # Should be the same instance due to lru_cache
        assert settings1 is settings2

    @patch.dict(
        "os.environ",
        {
            "SMTP_SERVER": "smtp.gmail.com",
            "SMTP_PORT": "587",
            "SMTP_USERNAME": "test@gmail.com",
            "SMTP_PASSWORD": "password123",
        },
    )
    def test_smtp_configuration(self):
        """Test SMTP configuration settings."""
        settings = Settings()

        assert settings.smtp_server == "smtp.gmail.com"
        assert settings.smtp_port == 587
        assert settings.smtp_username == "test@gmail.com"
        assert settings.smtp_password == "password123"
