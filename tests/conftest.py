from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """Test client fixture."""
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def mock_settings():
    """Mock settings for testing."""
    with patch("app.config.get_settings") as mock:
        mock.return_value.github_username = "testuser"
        mock.return_value.github_token = None
        mock.return_value.cache_ttl = 60
        mock.return_value.smtp_server = None
        mock.return_value.contact_email = "test@example.com"
        mock.return_value.debug = True
        yield mock.return_value


@pytest.fixture
def mock_github_response():
    """Mock GitHub API response."""
    return [
        {
            "clone_url": "https://github.com/testuser/repo1.git",
            "forks": 5,
            "name": "repo1",
            "language": "Python",
            "stargazers_count": 10,
            "html_url": "https://github.com/testuser/repo1",
            "description": "Test repository 1",
            "updated_at": "2024-01-01T00:00:00Z",
            "fork": False,
        },
        {
            "clone_url": "https://github.com/testuser/repo2.git",
            "forks": 2,
            "name": "repo2",
            "language": "JavaScript",
            "stargazers_count": 15,
            "html_url": "https://github.com/testuser/repo2",
            "description": "Test repository 2",
            "updated_at": "2024-01-02T00:00:00Z",
            "fork": False,
        },
    ]
