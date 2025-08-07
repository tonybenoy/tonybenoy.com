from app.utils import parse, sort_repos


class TestUtilityFunctions:
    """Test utility functions."""

    def test_sort_repos(self):
        """Test repository sorting by star count."""
        repos = [
            {"name": "repo1", "stargazers_count": 5},
            {"name": "repo2", "stargazers_count": 50},
            {"name": "repo3", "stargazers_count": 25},
            {"name": "repo4", "stargazers_count": 100},
        ]

        sorted_repos = sort_repos(repos, count=3)

        assert len(sorted_repos) == 3
        assert sorted_repos[0]["stargazers_count"] == 100
        assert sorted_repos[1]["stargazers_count"] == 50
        assert sorted_repos[2]["stargazers_count"] == 25

    def test_sort_repos_default_count(self):
        """Test repository sorting with default count."""
        repos = [{"name": f"repo{i}", "stargazers_count": i} for i in range(10)]

        sorted_repos = sort_repos(repos)

        assert len(sorted_repos) == 6  # Default count
        assert sorted_repos[0]["stargazers_count"] == 9
        assert sorted_repos[-1]["stargazers_count"] == 4

    def test_parse_link_header_simple(self):
        """Test parsing simple link header."""
        link_header = '<https://api.github.com/user/repos?page=2>; rel="next"'
        result = parse(link_header)

        assert "next" in result
        assert result["next"]["url"] == "https://api.github.com/user/repos?page=2"
        assert result["next"]["rel"] == "next"

    def test_parse_link_header_empty(self):
        """Test parsing empty link header."""
        result = parse("")
        assert result == {}

    def test_templates_configuration(self):
        """Test that templates are properly configured."""
        from app.utils import templates

        assert templates is not None
        assert hasattr(templates, "env")
        assert "current_year" in templates.env.globals
        assert isinstance(templates.env.globals["current_year"], int)
