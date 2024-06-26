from re import compile
from typing import Dict, List
from urllib.parse import parse_qsl, urlsplit

import httpx
from fastapi.templating import Jinja2Templates

templates = Jinja2Templates(directory="src/templates")


# SVG_TEMPLATE = """<?xml version="1.0"?>
#                 <svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="20">
#                 <rect width="30" height="20" fill="#555"/>
#                 <rect x="30" width="{recWidth}" height="20" fill="#4c1"/>
#                 <rect rx="3" width="80" height="20" fill="transparent"/>
#                     <g fill="#fff" text-anchor="middle"
#                     font-family="DejaVu Sans,Verdana,Geneva,sans-serif" font-size="11">
#                         <text x="15" y="14">Visits</text>
#                         <text x="{textX}" y="14">{count}</text>
#                     </g>
#                 </svg>
#                 """


# def get_svg(count: int, width: int, rec_width: int, text_x: int):
#     return SVG_TEMPLATE.format(
#         count=count, width=width, recWidth=rec_width, textX=text_x
#     )


# def calculate_svg_sizes(count: int):
#     text = str(count)
#     sizes = {"width": 80, "recWidth": 50, "textX": 55}
#     if len(text) > 5:
#         sizes["width"] += 6 * (len(text) - 5)
#         sizes["recWidth"] += 6 * (len(text) - 5)
#         sizes["textX"] += 3 * (len(text) - 5)

#     return sizes


# def get_db_conn() -> Connection:
#     if not path.exists("./db"):
#         Path("./db").mkdir(mode=0o777, parents=True, exist_ok=False)
#     conn = sqlite3.connect("./db/counter.db")
#     c = conn.cursor()
#     c.execute("""SELECT name FROM sqlite_master WHERE name='counter'""")
#     if not c.fetchone():
#         c.execute(
#             """CREATE TABLE counter
#              (count long,id int)"""
#         )
#         c.execute("""INSERT INTO counter values(1,1)""")
#     conn.commit()
#     return conn


# def update_count() -> int:
#     db_conn = get_db_conn()
#     c = db_conn.cursor()
#     c.execute("""SELECT count FROM counter WHERE id = 1;""")
#     cur_count = c.fetchone()
#     count = 0 if not cur_count else cur_count[0] + 1
#     c.execute("""UPDATE counter  SET count = ? WHERE id=1;""", (count,))
#     db_conn.commit()
#     db_conn.close()
#     return count


rlink = compile(r'<(.*?)>(.*?)rel="([A-z\s]*)"(.*?)(?:$|(?:,))')
assignations = compile(r'([A-z]*?)="(.*?)"')


def parse(link_header: str) -> Dict[str, Dict[str, str]]:
    # shamelessly copied from https://github.com/FlorianLouvetRN/linkheader_parser/blob/master/linkheader_parser/parser.py
    links = {}
    for match in rlink.finditer(link_header):
        parsed_content = {}
        link = match.group(1)
        rel = match.group(3)
        parsed_content["url"] = link
        query_params = dict(parse_qsl(urlsplit(link).query))
        parsed_content = {**parsed_content, **query_params}
        extra = match.group(2)
        if match.group(4) is not None:
            extra += match.group(4)
        for a in assignations.finditer(extra):
            parsed_content[a.group(1)] = a.group(2)
        for r in rel.split(" "):
            links[r] = {**parsed_content, **{"rel": r}}
    return links


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
                    "html_url": repo["html_url"],
                }
            )

    if "next" in links:
        response = get_repo_data_for_user(url=links["next"]["url"], response=response)
    return response


def sort_repos(repos: List[Dict[str, str]], count=6) -> List[Dict[str, str]]:
    return sorted(repos, key=lambda x: x["stargazers_count"], reverse=True)[:count]
