from unittest.mock import patch


def test_read_main(client):
    """Test home page endpoint."""
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers.get("content-type", "")


def test_test_endpoint(client):
    """Test simple test endpoint."""
    response = client.get("/test")
    assert response.status_code == 200
    assert response.json() == {"result": "It works!"}


def test_health_check_endpoint(client):
    """Test health check endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data
    assert "timestamp" in data


def test_favicon_redirect(client):
    """Test favicon redirect."""
    response = client.get("/favicon.ico", follow_redirects=True)
    assert response.status_code == 200


def test_myssh_redirect(client):
    """Test myssh script redirect."""
    response = client.get("/myssh", follow_redirects=True)
    assert response.status_code == 200


def test_client_ip_endpoint(client):
    """Test client IP endpoint."""
    response = client.get("/client_ip")
    assert response.status_code == 200
    data = response.json()
    assert "ip" in data
    assert "user_agent" in data


def test_llms_txt_endpoint(client):
    """Test llms.txt endpoint."""
    response = client.get("/llms.txt")
    assert response.status_code == 200
    assert response.headers["content-type"] == "text/plain; charset=utf-8"
    assert "Tony Benoy" in response.text


def test_llms_txt_fallback(client):
    """Test llms.txt endpoint when file doesn't exist."""
    with patch("builtins.open", side_effect=FileNotFoundError):
        response = client.get("/llms.txt")
        assert response.status_code == 200
        assert "Personal website of Tony Benoy" in response.text


def test_contact_page(client):
    """Test contact page."""
    response = client.get("/contact")
    assert response.status_code == 200
    assert "text/html" in response.headers.get("content-type", "")


def test_timeline_page(client):
    """Test timeline page."""
    response = client.get("/timeline")
    assert response.status_code == 200
    assert "text/html" in response.headers.get("content-type", "")


def test_terminal_page(client):
    """Test terminal page."""
    response = client.get("/terminal")
    assert response.status_code == 200
    assert "text/html" in response.headers.get("content-type", "")


def test_metrics_endpoint_without_psutil(client):
    """Test metrics endpoint when psutil is not available."""
    with patch.dict("sys.modules", {"psutil": None}):
        response = client.get("/metrics")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "message" in data


def test_contact_form_submission_no_smtp(client, mock_settings):
    """Test contact form submission without SMTP configuration."""
    form_data = {
        "name": "Test User",
        "email": "test@example.com",
        "subject": "Test Subject",
        "message": "This is a test message with enough content to pass validation.",
    }

    response = client.post("/contact", data=form_data)
    assert response.status_code == 200
    assert "text/html" in response.headers.get("content-type", "")


def test_contact_form_invalid_data(client):
    """Test contact form with invalid data."""
    # Test with empty form
    response = client.post("/contact", data={})
    assert response.status_code == 422  # Validation error

    # Test with short message
    form_data = {
        "name": "Test",
        "email": "test@example.com",
        "subject": "Test",
        "message": "Short",  # Too short
    }
    response = client.post("/contact", data=form_data)
    assert response.status_code == 422
