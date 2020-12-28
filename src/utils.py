from fastapi.templating import Jinja2Templates
import sqlite3
from sqlite3 import Connection
from pathlib import Path
from os import path
import httpx
from typing import List, Dict

templates = Jinja2Templates(directory="src/templates")


SVG_TEMPLATE = """<?xml version="1.0"?>
                <svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="20">
                <rect width="30" height="20" fill="#555"/>
                <rect x="30" width="{recWidth}" height="20" fill="#4c1"/>
                <rect rx="3" width="80" height="20" fill="transparent"/>
                    <g fill="#fff" text-anchor="middle"
                    font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
                        <text x="15" y="14">Visits</text>
                        <text x="{textX}" y="14">{count}</text>
                    </g>
                </svg>
                """


def get_svg(count: int, width: int, rec_width: int, text_x: int):
    return SVG_TEMPLATE.format(
        count=count, width=width, recWidth=rec_width, textX=text_x
    )


def calculate_svg_sizes(count: int):
    text = str(count)
    sizes = {"width": 80, "recWidth": 50, "textX": 55}
    if len(text) > 5:
        sizes["width"] += 6 * (len(text) - 5)
        sizes["recWidth"] += 6 * (len(text) - 5)
        sizes["textX"] += 3 * (len(text) - 5)

    return sizes


def get_db_conn() -> Connection:
    if not path.exists("./db"):
        Path("./db").mkdir(mode=0o777, parents=True, exist_ok=False)
    conn = sqlite3.connect("./db/counter.db")
    c = conn.cursor()
    c.execute("""SELECT name FROM sqlite_master WHERE name='counter'""")
    if not c.fetchone():
        c.execute(
            """CREATE TABLE counter
             (count long,id int)"""
        )
        c.execute("""INSERT INTO counter values(1,1)""")
    conn.commit()
    return conn


def update_count() -> int:
    db_conn = get_db_conn()
    c = db_conn.cursor()
    c.execute("""SELECT count FROM counter WHERE id = 1;""")
    cur_count = c.fetchone()
    count = 0 if not cur_count else cur_count[0] + 1
    c.execute("""UPDATE counter  SET count = ? WHERE id=1;""", (count,))
    db_conn.commit()
    db_conn.close()
    return count


def get_repo_data_for_user(
    url: str = "https://api.github.com/users/tonybenoy/repos", response: List = []
) -> List[Dict[str, str]]:
    resp = httpx.get(url)
    repos = resp.json()
    link = resp.headers["link"]
    links = parse(link)
    for repo in repos:
        if not repo["fork"]:
            response.append(
                {
                    "clone_url": repo["clone_url"],
                    "forks": repo["forks"],
                    "name": repo["name"],
                    "language": repo["language"],
                    "stargazers_count": repo["stargazers_count"],
                }
            )

    if "next" in links:
        response = get_repo_data_for_user(url=links["next"]["url"], response=response)
    return response