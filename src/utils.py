import logging
from datetime import datetime
from re import compile
from urllib.parse import parse_qsl, urlsplit

import httpx
from fastapi.templating import Jinja2Templates

templates = Jinja2Templates(directory="src/templates")
templates.env.globals["current_year"] = datetime.now().year


# Configure logging
logger = logging.getLogger(__name__)

# Configuration
GITHUB_API_BASE = "https://api.github.com"
DEFAULT_TIMEOUT = 30.0


rlink = compile(r'<(.*?)>(.*?)rel="([A-z\s]*)"(.*?)(?:$|(?:,))')
assignations = compile(r'([A-z]*?)="(.*?)"')


def parse(link_header: str) -> dict[str, dict[str, str]]:
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


async def get_repo_data_for_user(
    url: str = "https://api.github.com/users/tonybenoy/repos",
    response: list | None = None,
    github_token: str | None = None,
) -> list[dict[str, str]]:
    """
    Fetch GitHub repository data for a user with proper error handling.

    Args:
        url: GitHub API URL to fetch repos from
        response: Existing response list (for pagination)
        github_token: Optional GitHub token for higher rate limits

    Returns:
        List of repository data dictionaries

    Raises:
        httpx.HTTPError: For HTTP-related errors
        ValueError: For invalid response data
    """
    if response is None:
        response = []

    headers = {}
    if github_token:
        headers["Authorization"] = f"token {github_token}"

    timeout = httpx.Timeout(DEFAULT_TIMEOUT)

    try:
        async with httpx.AsyncClient(timeout=timeout, headers=headers) as client:
            resp = await client.get(url)
            resp.raise_for_status()

            repos = resp.json()
            if not isinstance(repos, list):
                logger.error(
                    f"Unexpected response format from GitHub API: {type(repos)}"
                )
                return response

            link = resp.headers.get("link", "")
            links = parse(link) if link else {}

            for repo in repos:
                if not repo.get("fork", True):  # Skip forks
                    try:
                        response.append(
                            {
                                "clone_url": repo.get("clone_url", ""),
                                "forks": repo.get("forks", 0),
                                "name": repo.get("name", "Unknown"),
                                "language": repo.get("language") or "Not specified",
                                "stargazers_count": repo.get("stargazers_count", 0),
                                "html_url": repo.get("html_url", ""),
                                "description": repo.get("description", ""),
                                "updated_at": repo.get("updated_at", ""),
                            }
                        )
                    except KeyError as e:
                        logger.warning(f"Missing expected field in repo data: {e}")
                        continue

            if "next" in links:
                response = await get_repo_data_for_user(
                    url=links["next"]["url"],
                    response=response,
                    github_token=github_token,
                )

    except httpx.TimeoutException:
        logger.error(f"Timeout while fetching data from {url}")
        raise
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error {e.response.status_code} while fetching {url}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error while fetching repo data: {e}")
        raise

    return response


def sort_repos(repos: list[dict[str, str]], count: int = 6) -> list[dict[str, str]]:
    return sorted(repos, key=lambda x: x["stargazers_count"], reverse=True)[:count]
