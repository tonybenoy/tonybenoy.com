from unittest.mock import patch


class TestAppsRoute:
    """Test the apps route functionality."""

    def test_apps_view_basic(self, client):
        """Test basic apps view functionality."""
        # Mock the GitHub API to avoid external calls
        with patch("app.routes.apps.get_repo_data_for_user") as mock_fetch:
            mock_fetch.return_value = []

            response = client.get("/app")
            assert response.status_code == 200
            assert "text/html" in response.headers.get("content-type", "")

    def test_apps_view_with_mock_data(self, client, mock_github_response):
        """Test apps view with mocked data."""
        with (
            patch("app.routes.apps.get_repo_data_for_user") as mock_fetch,
            patch("app.routes.apps.sort_repos") as mock_sort,
        ):
            mock_fetch.return_value = mock_github_response
            mock_sort.return_value = mock_github_response

            response = client.get("/app")
            assert response.status_code == 200


class TestHomeRoutes:
    """Test home route functionality."""

    def test_index_route(self, client):
        """Test the index route."""
        response = client.get("/")
        assert response.status_code == 200
        assert "text/html" in response.headers.get("content-type", "")

    def test_timeline_page(self, client):
        """Test timeline page."""
        response = client.get("/timeline")
        assert response.status_code == 200
        assert "text/html" in response.headers.get("content-type", "")

    def test_terminal_page(self, client):
        """Test terminal page."""
        response = client.get("/terminal")
        assert response.status_code == 200
        assert "text/html" in response.headers.get("content-type", "")

    def test_contact_form_basic(self, client):
        """Test basic contact form functionality."""
        form_data = {
            "name": "John Doe",
            "email": "john@example.com",
            "subject": "Test Subject Here",
            "message": "This is a test message with sufficient length.",
        }

        response = client.post("/contact", data=form_data)
        assert response.status_code == 200


class TestErrorHandling:
    """Test error handling in routes."""

    def test_404_routes(self, client):
        """Test 404 handling for non-existent routes."""
        response = client.get("/nonexistent-route")
        assert response.status_code == 404
