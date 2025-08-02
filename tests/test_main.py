from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_read_main():
    response = client.get("/")
    assert response.status_code == 200


def test_test_endpoint():
    response = client.get("/test")
    assert response.status_code == 200
    assert response.json() == {"result": "It works!"}


def test_health_check_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_favicon_redirect():
    response = client.get("/favicon.ico")
    assert response.status_code == 200
    assert response.headers["content-type"] == "image/vnd.microsoft.icon"


def test_myssh_redirect():
    response = client.get("/myssh")
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/x-sh"
