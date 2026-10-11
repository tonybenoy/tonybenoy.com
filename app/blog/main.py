"""Musings (from blog-inker): single-user blog with long posts and tweet-like notes.

Exposed as ``blog_app`` and mounted at ``/musings`` by ``app.main``.
"""

import hashlib
import hmac
import os
import re
import secrets
import sqlite3
import uuid
from contextvars import ContextVar
from datetime import UTC, datetime
from email.utils import format_datetime
from pathlib import Path
from urllib.parse import urlencode
from xml.sax.saxutils import escape as xml_escape

import markdown as md
import nh3
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import (
    FileResponse,
    JSONResponse,
    PlainTextResponse,
    RedirectResponse,
    Response,
)
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from PIL import Image, ImageOps
from starlette.middleware.sessions import SessionMiddleware

BASE = Path(__file__).parent
PREFIX = "/musings"  # mount point; every URL the blog emits is prefixed with this
DATA = Path(os.environ.get("BLOG_DATA", BASE.parents[1] / "blog-data"))
UPLOADS = DATA / "uploads"
UPLOADS.mkdir(parents=True, exist_ok=True)
DB_PATH = DATA / "blog.db"
MAX_UPLOAD = 25 * 1024 * 1024


def _secret():
    if os.environ.get("BLOG_SECRET"):
        return os.environ["BLOG_SECRET"]
    f = DATA / ".secret"
    if not f.exists():
        f.write_text(secrets.token_hex(32))
    return f.read_text().strip()


ADMIN_PASSWORD = os.environ.get("BLOG_PASSWORD", "")  # empty = login disabled
SITE = {
    "name": os.environ.get("BLOG_NAME", "Tony Benoy"),
    "tagline": os.environ.get(
        "BLOG_TAGLINE", "Notes, essays and half-formed thoughts."
    ),
    "url": os.environ.get("BLOG_URL", "https://tonybenoy.com").rstrip("/"),
    "twitter": os.environ.get("BLOG_TWITTER", "@TonyBenoy"),
    "home": os.environ.get("BLOG_HOME", "https://tonybenoy.com"),
}
PER_PAGE = 12
NOTE_MAX = 500

blog_app = app = FastAPI(title="blog", docs_url=None, redoc_url=None, openapi_url=None)
app.add_middleware(
    SessionMiddleware,
    secret_key=_secret(),
    same_site="lax",
    max_age=60 * 60 * 24 * 30,
    https_only=bool(os.environ.get("BLOG_HTTPS")),
    path=PREFIX,
)
app.mount("/static", StaticFiles(directory=BASE / "static"), name="static")
templates = Jinja2Templates(directory=BASE / "templates")

SCHEMA = """
CREATE TABLE IF NOT EXISTS posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL DEFAULT 'post',          -- 'post' | 'note'
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL DEFAULT '',
  body TEXT NOT NULL DEFAULT '',
  excerpt TEXT NOT NULL DEFAULT '',            -- SEO meta description
  cover TEXT NOT NULL DEFAULT '',
  tags TEXT NOT NULL DEFAULT '',               -- comma separated, lowercase
  published INTEGER NOT NULL DEFAULT 1,
  pinned INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tags (
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  PRIMARY KEY (post_id, tag)
);
CREATE INDEX IF NOT EXISTS idx_tags_tag ON tags(tag);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at);
CREATE VIRTUAL TABLE IF NOT EXISTS posts_fts USING fts5(
  title, body, tags, content='posts', content_rowid='id', tokenize='porter unicode61'
);
CREATE TRIGGER IF NOT EXISTS posts_ai AFTER INSERT ON posts BEGIN
  INSERT INTO posts_fts(rowid,title,body,tags) VALUES (new.id,new.title,new.body,new.tags);
END;
CREATE TRIGGER IF NOT EXISTS posts_ad AFTER DELETE ON posts BEGIN
  INSERT INTO posts_fts(posts_fts,rowid,title,body,tags) VALUES ('delete',old.id,old.title,old.body,old.tags);
END;
CREATE TRIGGER IF NOT EXISTS posts_au AFTER UPDATE ON posts BEGIN
  INSERT INTO posts_fts(posts_fts,rowid,title,body,tags) VALUES ('delete',old.id,old.title,old.body,old.tags);
  INSERT INTO posts_fts(rowid,title,body,tags) VALUES (new.id,new.title,new.body,new.tags);
END;
"""

_db: ContextVar = ContextVar("db")
_req: ContextVar = ContextVar("req")


def init_db():
    c = sqlite3.connect(DB_PATH)
    c.executescript(SCHEMA)
    c.commit()
    c.close()


init_db()


@app.middleware("http")
async def request_scope(request: Request, call_next):
    """Per-request DB connection + CSRF check for form posts."""
    con = sqlite3.connect(DB_PATH, check_same_thread=False)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys=ON")
    t1, t2 = _db.set(con), _req.set(request)
    try:
        return await call_next(request)
    finally:
        con.close()
        _db.reset(t1)
        _req.reset(t2)


def db() -> sqlite3.Connection:
    return _db.get()


# ---------------------------------------------------------------- routing helpers

ROUTES = {
    "index": "/",
    "tags_page": "/tags",
    "drafts": "/drafts",
    "login": "/login",
    "logout": "/logout",
    "post": "/p/{slug}",
    "edit": "/edit/{pid}",
    "new": "/new/{kind}",
    "delete": "/delete/{pid}",
    "feed": "/feed.xml",
    "static": "/static/{path}",
}


def url_for(name, **kw):
    path = ROUTES[name]
    for k in re.findall(r"{(\w+)}", path):
        path = path.replace(f"{{{k}}}", str(kw.pop(k)))
    q = {k: v for k, v in kw.items() if v not in (None, "", False)}
    return PREFIX + path + ("?" + urlencode(q) if q else "")


def abs_url(path):
    """Absolute URL for an already-prefixed path."""
    return SITE["url"] + path


def media_url(path):
    if not path:
        return ""
    return path if path.startswith("http") else abs_url(path)


def render(request: Request, name: str, status=200, **ctx):
    s = request.session
    if "csrf" not in s:
        s["csrf"] = secrets.token_hex(16)
    cur = request.url.path.removeprefix(PREFIX) or "/"
    ctx.update(
        request=request,
        site=SITE,
        base=PREFIX,
        cur=cur,
        NOTE_MAX=NOTE_MAX,
        url_for=url_for,
        media_url=media_url,
        csrf=s["csrf"],
        is_admin=bool(s.get("admin")),
        flashes=s.pop("flash", []),
        current_year=datetime.now().year,
    )
    return templates.TemplateResponse(request, name, ctx, status_code=status)


def flash(request, msg, cat="ok"):
    request.session["flash"] = request.session.get("flash", []) + [[cat, msg]]


def redirect(url):
    return RedirectResponse(
        PREFIX + url if url.startswith("/") else url, status_code=303
    )


def redirect_to(prefixed_url):
    return RedirectResponse(prefixed_url, status_code=303)


def is_admin(request):
    return bool(request.session.get("admin"))


def require_admin(request):
    if not is_admin(request):
        raise HTTPException(
            303,
            headers={
                "Location": PREFIX
                + "/login?"
                + urlencode({"next": request.url.path.removeprefix(PREFIX)})
            },
        )


async def check_csrf(request: Request, token: str = ""):
    if not hmac.compare_digest(
        token or request.headers.get("x-csrf", ""), request.session.get("csrf", "-")
    ):
        raise HTTPException(400, "Bad CSRF token")


# ---------------------------------------------------------------- content helpers

ALLOWED_TAGS = nh3.ALLOWED_TAGS | {
    "img",
    "figure",
    "figcaption",
    "pre",
    "code",
    "hr",
    "u",
    "mark",
    "table",
    "thead",
    "tbody",
    "tr",
    "th",
    "td",
    "del",
    "sup",
    "sub",
}
ALLOWED_ATTRS = {
    "a": {"href", "title", "class"},
    "img": {"src", "alt", "title", "loading"},
    "code": {"class"},
    "pre": {"class"},
    "th": {"align"},
    "td": {"align"},
}


def render_md(text):
    html = md.markdown(text or "", extensions=["fenced_code", "tables", "sane_lists"])
    html = nh3.clean(
        html,
        tags=ALLOWED_TAGS,
        attributes=ALLOWED_ATTRS,
        link_rel="noopener noreferrer nofollow",
        url_schemes={"http", "https", "mailto"},
    )
    return html.replace("<img ", '<img loading="lazy" ')


def linkify_note(text):
    """Notes: markdown + auto-links + clickable #hashtags."""
    html = render_md(text)
    html = re.sub(
        r'(?<![">/\w=])(https?://[^\s<]+)',
        r'<a href="\1" rel="noopener nofollow">\1</a>',
        html,
    )
    html = re.sub(
        r'(?<![\w&/#"=])#([A-Za-z][\w-]{1,30})',
        lambda m: (
            f'<a class="hashtag" href="{PREFIX}/?tag={m.group(1).lower()}">#{m.group(1)}</a>'
        ),
        html,
    )
    return html


def strip_text(text, n=None):
    t = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text or "")
    t = re.sub(r"https?://\S+", "", t)
    t = re.sub(r"[#*_`>\[\]()~|]+", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    if n and len(t) > n:
        t = t[:n].rsplit(" ", 1)[0].rstrip(".,;:") + "…"
    return t


def first_image(body):
    m = re.search(r"!\[[^\]]*\]\(([^)\s]+)", body or "")
    return m.group(1) if m else ""


def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", (s or "").lower()).strip("-")[:70].strip("-")


def unique_slug(base, exclude_id=None):
    base = base or "note-" + secrets.token_hex(3)
    slug, i = base, 2
    while True:
        r = db().execute("SELECT id FROM posts WHERE slug=?", (slug,)).fetchone()
        if not r or r["id"] == exclude_id:
            return slug
        slug, i = f"{base}-{i}", i + 1


def parse_tags(raw):
    out = []
    for t in re.split(r"[,\n]", raw or ""):
        t = (
            re.sub(r"[^a-z0-9+#. -]", "", t.strip().lower().lstrip("#"))
            .strip()
            .replace(" ", "-")
        )
        if t and t not in out:
            out.append(t[:30])
    return out[:12]


def now():
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%S")


def parse_dt(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%S").replace(tzinfo=UTC)


def f_iso(s):
    return parse_dt(s).strftime("%Y-%m-%dT%H:%M:%SZ")


def f_date(s, fmt="%b %d, %Y"):
    return parse_dt(s).strftime(fmt).replace(" 0", " ")


def f_ago(s):
    d = (datetime.now(UTC) - parse_dt(s)).total_seconds()
    if d < 60:
        return "just now"
    if d < 3600:
        return f"{int(d // 60)}m"
    if d < 86400:
        return f"{int(d // 3600)}h"
    if d < 86400 * 7:
        return f"{int(d // 86400)}d"
    return f_date(s)


templates.env.filters.update(
    date=f_date,
    iso=f_iso,
    ago=f_ago,
    taglist=lambda s: [t for t in (s or "").split(",") if t],
    strip_text=strip_text,
)


def hydrate(row):
    p = dict(row)
    p["html"] = linkify_note(p["body"]) if p["kind"] == "note" else render_md(p["body"])
    p["summary"] = p["excerpt"] or strip_text(p["body"], 180)
    p["reading"] = max(1, round(len((p["body"] or "").split()) / 220))
    p["image"] = p["cover"] or first_image(p["body"])
    return p


# ---------------------------------------------------------------- auth


@app.get("/login")
def login_form(request: Request):
    return render(request, "login.html", meta={"title": "Sign in", "noindex": True})


@app.post("/login")
async def login(
    request: Request, password: str = Form(""), next: str = "", csrf: str = Form("")
):
    await check_csrf(request, csrf)

    def h(x):
        return hashlib.sha256(x.encode()).digest()

    if ADMIN_PASSWORD and hmac.compare_digest(h(password), h(ADMIN_PASSWORD)):
        request.session.clear()
        request.session["admin"] = True
        return redirect(
            next if next.startswith("/") and not next.startswith("//") else "/"
        )
    flash(request, "Wrong password.", "error")
    return redirect("/login")


@app.post("/logout")
async def logout(request: Request, csrf: str = Form("")):
    await check_csrf(request, csrf)
    request.session.clear()
    return redirect("/")


# ---------------------------------------------------------------- public

SORTS = {
    "new": ("Newest", "p.pinned DESC, p.created_at DESC"),
    "old": ("Oldest", "p.created_at ASC"),
    "az": (
        "A–Z",
        "CASE WHEN p.title='' THEN p.body ELSE p.title END COLLATE NOCASE ASC",
    ),
}


def query_posts(kind=None, tag=None, q=None, sort="new", page=1):
    where, args, join = ["p.published=1"], [], ""
    if kind in ("post", "note"):
        where.append("p.kind=?")
        args.append(kind)
    if tag:
        where.append("p.id IN (SELECT post_id FROM tags WHERE tag=?)")
        args.append(tag)
    order = SORTS.get(sort, SORTS["new"])[1]
    if q:
        fq = " ".join(f'"{w}"*' for w in re.findall(r"[\w+#.-]+", q)[:8])
        if fq:
            join = "JOIN posts_fts ON posts_fts.rowid=p.id"
            where.append("posts_fts MATCH ?")
            args.append(fq)
            if sort == "rel":
                order = "bm25(posts_fts, 8, 1, 4)"
    w = "WHERE " + " AND ".join(where)
    total = db().execute(f"SELECT COUNT(*) FROM posts p {join} {w}", args).fetchone()[0]
    rows = (
        db()
        .execute(
            f"SELECT p.* FROM posts p {join} {w} ORDER BY {order} LIMIT ? OFFSET ?",
            args + [PER_PAGE, (page - 1) * PER_PAGE],
        )
        .fetchall()
    )
    return [hydrate(r) for r in rows], total


def tag_counts():
    return (
        db()
        .execute(
            "SELECT t.tag, COUNT(*) n FROM tags t JOIN posts p ON p.id=t.post_id WHERE p.published=1 "
            "GROUP BY t.tag ORDER BY n DESC, t.tag"
        )
        .fetchall()
    )


@app.get("/")
def index(
    request: Request,
    type: str = "",
    tag: str = "",
    q: str = "",
    sort: str = "",
    page: int = 1,
):
    kind, tag, q = type, tag.strip().lower(), q.strip()
    sort = sort or ("rel" if q else "new")
    page = max(1, page)
    posts, total = query_posts(kind, tag, q, sort, page)
    pages = max(1, -(-total // PER_PAGE))
    title = SITE["name"] + " — Musings"
    if q:
        title = f"Search: {q}"
    elif tag:
        title = f"#{tag}"
    elif kind in ("post", "note"):
        title = {"post": "Posts", "note": "Notes"}[kind]
    meta = {
        "title": title,
        "description": SITE["tagline"],
        "noindex": bool(q) or page > 1,
        "canonical": None if q else abs_url(url_for("index", tag=tag, type=kind)),
        "home": not (q or tag or kind),
    }
    n_drafts = (
        db().execute("SELECT COUNT(*) FROM posts WHERE published=0").fetchone()[0]
        if is_admin(request)
        else 0
    )
    return render(
        request,
        "index.html",
        posts=posts,
        total=total,
        page=page,
        pages=pages,
        kind=kind,
        tag=tag,
        q=q,
        sort=sort,
        sorts=SORTS,
        tags=tag_counts()[:30],
        meta=meta,
        drafts=n_drafts,
    )


@app.get("/drafts")
def drafts(request: Request):
    require_admin(request)
    rows = (
        db()
        .execute("SELECT * FROM posts WHERE published=0 ORDER BY updated_at DESC")
        .fetchall()
    )
    return render(
        request,
        "drafts.html",
        posts=[hydrate(r) for r in rows],
        meta={"title": "Drafts", "noindex": True},
    )


@app.get("/tags")
def tags_page(request: Request):
    return render(
        request,
        "tags.html",
        tags=tag_counts(),
        meta={"title": "Tags", "description": "Browse everything by topic."},
    )


@app.get("/p/{slug}")
def post(request: Request, slug: str):
    r = db().execute("SELECT * FROM posts WHERE slug=?", (slug,)).fetchone()
    if not r or (not r["published"] and not is_admin(request)):
        raise HTTPException(404)
    p = hydrate(r)
    ts = [t for t in p["tags"].split(",") if t]
    related = []
    if ts:
        ph = ",".join("?" * len(ts))
        related = [
            hydrate(x)
            for x in db().execute(
                f"SELECT p.* FROM posts p JOIN tags t ON t.post_id=p.id WHERE t.tag IN ({ph}) AND p.id!=? AND p.published=1 "
                "GROUP BY p.id ORDER BY COUNT(*) DESC, p.created_at DESC LIMIT 3",
                ts + [p["id"]],
            )
        ]
    adj = "SELECT slug,title,body FROM posts WHERE published=1 AND created_at{op}? ORDER BY created_at {d} LIMIT 1"
    older = db().execute(adj.format(op="<", d="DESC"), (p["created_at"],)).fetchone()
    newer = db().execute(adj.format(op=">", d="ASC"), (p["created_at"],)).fetchone()
    title = p["title"] or strip_text(p["body"], 60) or "Note"
    meta = {
        "title": title,
        "description": p["summary"],
        "type": "article",
        "image": media_url(p["image"]),
        "canonical": abs_url(url_for("post", slug=slug)),
        "published": f_iso(p["created_at"]),
        "modified": f_iso(p["updated_at"]),
        "tags": ts,
        "noindex": not p["published"],
    }
    return render(
        request,
        "post.html",
        p=p,
        tags=ts,
        related=related,
        older=older,
        newer=newer,
        meta=meta,
    )


@app.get("/uploads/{name:path}")
def uploads(name: str):
    path = (UPLOADS / name).resolve()
    if UPLOADS.resolve() not in path.parents or not path.is_file():
        raise HTTPException(404)
    return FileResponse(
        path, headers={"Cache-Control": "public, max-age=31536000, immutable"}
    )


# ---------------------------------------------------------------- write


def tags_from_note(body):
    return re.findall(
        r"(?<![\w&/#])#([A-Za-z][\w-]{1,30})", re.sub(r"\(.*?\)", "", body)
    )


def store(kind, f, pid=None):
    body = f.get("body", "").strip()
    title = f.get("title", "").strip()[:200] if kind == "post" else ""
    if kind == "post" and not (title and body):
        return None, "A post needs a title and body."
    if not body:
        return None, "Write something first."
    if kind == "note" and len(re.sub(r"!\[[^\]]*\]\([^)]*\)", "", body)) > NOTE_MAX:
        return None, f"Notes are limited to {NOTE_MAX} characters."
    tags = parse_tags(f.get("tags", ""))
    if kind == "note":
        tags += [t.lower() for t in tags_from_note(body) if t.lower() not in tags]
        tags = tags[:12]
    excerpt = f.get("excerpt", "").strip()[:200] if kind == "post" else ""
    cover = f.get("cover", "").strip() if kind == "post" else ""
    published = 0 if f.get("action") == "draft" else 1
    pinned = 1 if f.get("pinned") else 0
    t = now()
    if pid is None:
        slug = unique_slug(slugify(f.get("slug") or title) if kind == "post" else "")
        pid = (
            db()
            .execute(
                "INSERT INTO posts(kind,slug,title,body,excerpt,cover,tags,published,pinned,created_at,updated_at)"
                " VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                (
                    kind,
                    slug,
                    title,
                    body,
                    excerpt,
                    cover,
                    ",".join(tags),
                    published,
                    pinned,
                    t,
                    t,
                ),
            )
            .lastrowid
        )
    else:
        old = db().execute("SELECT slug FROM posts WHERE id=?", (pid,)).fetchone()
        slug = (
            unique_slug(slugify(f.get("slug")) or old["slug"], pid)
            if kind == "post"
            else old["slug"]
        )
        db().execute(
            "UPDATE posts SET slug=?,title=?,body=?,excerpt=?,cover=?,tags=?,published=?,pinned=?,updated_at=? WHERE id=?",
            (
                slug,
                title,
                body,
                excerpt,
                cover,
                ",".join(tags),
                published,
                pinned,
                t,
                pid,
            ),
        )
    db().execute("DELETE FROM tags WHERE post_id=?", (pid,))
    db().executemany(
        "INSERT OR IGNORE INTO tags VALUES (?,?)", [(pid, x) for x in tags]
    )
    db().commit()
    return slug, None


@app.get("/new/{kind}")
def new_form(request: Request, kind: str):
    require_admin(request)
    if kind not in ("post", "note"):
        raise HTTPException(404)
    return render(
        request,
        "editor.html",
        p={"kind": kind, "published": 1},
        meta={"title": f"New {kind}", "noindex": True},
    )


@app.post("/new/{kind}")
async def new(request: Request, kind: str):
    require_admin(request)
    if kind not in ("post", "note"):
        raise HTTPException(404)
    f = await request.form()
    await check_csrf(request, f.get("csrf", ""))
    slug, err = store(kind, f)
    if err:
        flash(request, err, "error")
        return render(
            request,
            "editor.html",
            p={"kind": kind, **dict(f)},
            meta={"title": f"New {kind}", "noindex": True},
        )
    draft = f.get("action") == "draft"
    flash(request, "Draft saved." if draft else "Published.")
    return redirect("/drafts") if draft else redirect_to(url_for("post", slug=slug))


@app.get("/edit/{pid}")
def edit_form(request: Request, pid: int):
    require_admin(request)
    r = db().execute("SELECT * FROM posts WHERE id=?", (pid,)).fetchone()
    if not r:
        raise HTTPException(404)
    return render(
        request, "editor.html", p=dict(r), meta={"title": "Edit", "noindex": True}
    )


@app.post("/edit/{pid}")
async def edit(request: Request, pid: int):
    require_admin(request)
    r = db().execute("SELECT * FROM posts WHERE id=?", (pid,)).fetchone()
    if not r:
        raise HTTPException(404)
    f = await request.form()
    await check_csrf(request, f.get("csrf", ""))
    slug, err = store(r["kind"], f, pid)
    if err:
        flash(request, err, "error")
        return render(
            request,
            "editor.html",
            p={**dict(r), **dict(f)},
            meta={"title": "Edit", "noindex": True},
        )
    flash(request, "Saved.")
    return redirect_to(url_for("post", slug=slug))


@app.post("/delete/{pid}")
async def delete(request: Request, pid: int, csrf: str = Form("")):
    require_admin(request)
    await check_csrf(request, csrf)
    db().execute("DELETE FROM posts WHERE id=?", (pid,))
    db().commit()
    flash(request, "Deleted.")
    return redirect("/")


@app.post("/upload")
async def upload(request: Request, files: list[UploadFile] = File(...)):
    require_admin(request)
    await check_csrf(request)
    out = []
    for f in files:
        try:
            data = await f.read()
            if len(data) > MAX_UPLOAD:
                raise ValueError
            import io

            im = Image.open(io.BytesIO(data))
            sub = f"{datetime.now():%Y/%m}"
            (UPLOADS / sub).mkdir(parents=True, exist_ok=True)
            if im.format == "GIF" and getattr(im, "is_animated", False):
                name = f"{sub}/{uuid.uuid4().hex[:12]}.gif"
                (UPLOADS / name).write_bytes(data)
            else:
                im = ImageOps.exif_transpose(im)  # also drops EXIF (GPS etc.)
                im.thumbnail((2000, 2000))
                alpha = im.mode in ("RGBA", "LA", "P")
                name = f"{sub}/{uuid.uuid4().hex[:12]}.{'png' if alpha else 'jpg'}"
                if alpha:
                    im.convert("RGBA").save(UPLOADS / name, optimize=True)
                else:
                    im.convert("RGB").save(
                        UPLOADS / name, quality=85, optimize=True, progressive=True
                    )
            out.append(
                {
                    "url": PREFIX + "/uploads/" + name,
                    "name": Path(f.filename or "image").stem,
                }
            )
        except Exception:
            return JSONResponse(
                {"error": f"{f.filename}: not a valid image"}, status_code=400
            )
    return {"files": out}


@app.post("/preview")
async def preview(request: Request, body: str = Form(""), kind: str = Form("post")):
    require_admin(request)
    await check_csrf(request)
    return {"html": linkify_note(body) if kind == "note" else render_md(body)}


# ---------------------------------------------------------------- SEO / feeds


@app.get("/feed.xml")
def feed():
    rows = (
        db()
        .execute(
            "SELECT * FROM posts WHERE published=1 ORDER BY created_at DESC LIMIT 30"
        )
        .fetchall()
    )
    items = []
    for r in rows:
        p = hydrate(r)
        link = abs_url(url_for("post", slug=p["slug"]))
        title = p["title"] or strip_text(p["body"], 70)
        html = (
            p["html"]
            .replace(f'src="{PREFIX}/uploads', f'src="{abs_url(PREFIX + "/uploads")}')
            .replace("]]>", "]]]]><![CDATA[>")
        )
        items.append(
            f"<item><title>{xml_escape(title)}</title><link>{link}</link><guid>{link}</guid>"
            f"<pubDate>{format_datetime(parse_dt(p['created_at']))}</pubDate>"
            f"<description>{xml_escape(p['summary'])}</description>"
            f"<content:encoded><![CDATA[{html}]]></content:encoded></item>"
        )
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?><rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/" '
        'xmlns:atom="http://www.w3.org/2005/Atom"><channel>'
        f"<title>{xml_escape(SITE['name'])}</title><link>{abs_url(PREFIX + '/')}</link>"
        f"<description>{xml_escape(SITE['tagline'])}</description>"
        f'<atom:link href="{abs_url(PREFIX + "/feed.xml")}" rel="self" type="application/rss+xml"/>'
        + "".join(items)
        + "</channel></rss>"
    )
    return Response(xml, media_type="application/rss+xml")


@app.get("/sitemap.xml")
def sitemap():
    urls = [(abs_url(url_for("index")), None), (abs_url(url_for("tags_page")), None)]
    for r in db().execute(
        "SELECT slug,updated_at FROM posts WHERE published=1 ORDER BY created_at DESC"
    ):
        urls.append((abs_url(url_for("post", slug=r["slug"])), f_iso(r["updated_at"])))
    for t in tag_counts():
        urls.append((abs_url(url_for("index", tag=t["tag"])), None))
    body = "".join(
        f"<url><loc>{xml_escape(u)}</loc>"
        + (f"<lastmod>{m}</lastmod>" if m else "")
        + "</url>"
        for u, m in urls
    )
    return Response(
        '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + body
        + "</urlset>",
        media_type="application/xml",
    )


@app.get("/robots.txt")
def robots():
    return PlainTextResponse(
        f"User-agent: *\nDisallow: {PREFIX}/login\nDisallow: {PREFIX}/drafts\nDisallow: {PREFIX}/edit/\n"
        f"Disallow: {PREFIX}/new/\nDisallow: {PREFIX}/?q=\n\nSitemap: {abs_url(PREFIX + '/sitemap.xml')}\n"
    )


@app.exception_handler(HTTPException)
async def http_error(request: Request, exc: HTTPException):
    if exc.status_code == 303:
        return RedirectResponse(exc.headers["Location"], status_code=303)
    if exc.status_code == 404:
        return render(
            request,
            "404.html",
            status=404,
            meta={"title": "Not found", "noindex": True},
        )
    return PlainTextResponse(str(exc.detail), status_code=exc.status_code)
