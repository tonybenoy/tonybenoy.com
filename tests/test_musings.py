"""Musings (blog sub-app mounted at /musings)."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_musings_index():
    r = client.get("/musings/")
    assert r.status_code == 200
    assert "Musings" in r.text
    assert 'href="/musings/static/css/style.css"' in r.text


def test_main_nav_links_to_musings():
    assert 'href="/musings/"' in client.get("/").text


def test_admin_pages_require_login():
    r = client.get("/musings/drafts", follow_redirects=False)
    assert r.status_code == 303
    assert r.headers["location"].startswith("/musings/login")


def test_legacy_blog_urls_redirect():
    r = client.get("/blog/p/some-post?x=1", follow_redirects=False)
    assert r.status_code == 308
    assert r.headers["location"] == "/musings/p/some-post?x=1"
    assert (
        client.get("/blog", follow_redirects=False).headers["location"] == "/musings/"
    )
