#!/usr/bin/env python3
"""
Fetch GitHub Copilot Pull Request Reviews

This script fetches pull request reviews from GitHub and filters for Copilot reviews.
It supports both PR numbers and full GitHub PR URLs as input.

Usage:
    python fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
    python fetch_copilot_reviews.py --pr https://github.com/owner/repo/pull/123
    python fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --output reviews.json
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Any


def check_gh_cli() -> bool:
    """Check if gh CLI is available and authenticated."""
    try:
        result = subprocess.run(
            ["gh", "auth", "status"],
            capture_output=True,
            text=True,
        )
        return result.returncode == 0
    except (FileNotFoundError, OSError):
        return False


def parse_pr_url(pr_input: str) -> tuple[Optional[str], Optional[str], Optional[int]]:
    """
    Parse a GitHub PR URL to extract owner, repo, and PR number.

    Supports formats:
    - https://github.com/owner/repo/pull/123
    - https://www.github.com/owner/repo/pull/123

    Returns:
        (owner, repo, pr_number) or (None, None, None) if not a URL
    """
    url_pattern = r"https?://(?:www\.)?github\.com/([^/]+)/([^/]+)/pull/(\d+)"
    match = re.match(url_pattern, pr_input)

    if match:
        owner, repo, pr_number = match.groups()
        return owner, repo, int(pr_number)

    return None, None, None


def fetch_reviews(owner: str, repo: str, pr_number: int, use_gh_cli: bool, token: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    Fetch all reviews for a pull request.

    Args:
        owner: Repository owner
        repo: Repository name
        pr_number: Pull request number
        use_gh_cli: Use gh CLI if available and authenticated
        token: GitHub authentication token (optional, only used if use_gh_cli is False)

    Returns:
        List of review objects

    Raises:
        RuntimeError: On API errors
    """
    if use_gh_cli:
        try:
            result = subprocess.run(
                ["gh", "api", f"repos/{owner}/{repo}/pulls/{pr_number}/reviews"],
                capture_output=True,
                text=True,
                check=True,
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            stderr = e.stderr.strip()
            if "401" in stderr or "Unauthorized" in stderr:
                raise RuntimeError("Unauthorized. Run 'gh auth login' to authenticate.")
            elif "404" in stderr or "Not Found" in stderr:
                raise RuntimeError(f"Not Found. PR {pr_number} not found in {owner}/{repo}.")
            else:
                raise RuntimeError(f"GitHub API error: {stderr}")
        except (FileNotFoundError, OSError) as e:
            raise RuntimeError(f"gh CLI not available: {e}")

    try:
        import requests
    except ImportError:
        import urllib.request
        import urllib.error

        url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/reviews"
        headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        }

        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode("utf-8"))
                return data
        except urllib.error.HTTPError as e:
            error_msg = f"HTTP Error {e.code}: "
            if e.code == 401:
                error_msg += "Unauthorized. Check your GitHub token."
            elif e.code == 403:
                error_msg += "Forbidden. Check rate limits or permissions."
            elif e.code == 404:
                error_msg += f"Not Found. PR {pr_number} not found in {owner}/{repo}."
            else:
                error_msg += str(e.reason)
            raise RuntimeError(error_msg) from e
        except urllib.error.URLError as e:
            raise RuntimeError(f"Network Error: {e.reason}") from e

    url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/reviews"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()


def fetch_review_comments(
    owner: str, repo: str, pr_number: int, review_id: int, use_gh_cli: bool, token: Optional[str] = None
) -> List[Dict[str, Any]]:
    """
    Fetch comments for a specific review.

    Args:
        owner: Repository owner
        repo: Repository name
        pr_number: Pull request number
        review_id: Review ID
        use_gh_cli: Use gh CLI if available and authenticated
        token: GitHub authentication token (optional, only used if use_gh_cli is False)

    Returns:
        List of comment objects

    Raises:
        RuntimeError: On API errors
    """
    if use_gh_cli:
        try:
            result = subprocess.run(
                ["gh", "api", f"repos/{owner}/{repo}/pulls/{pr_number}/reviews/{review_id}/comments"],
                capture_output=True,
                text=True,
                check=True,
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError:
            return []

    try:
        import requests
    except ImportError:
        import urllib.request
        import urllib.error

        url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/reviews/{review_id}/comments"
        headers = {
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
        }

        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            return []
        except urllib.error.URLError as e:
            raise RuntimeError(f"Network Error: {e.reason}") from e

    url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}/reviews/{review_id}/comments"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()


def validate_output_path(output_path: str) -> Path:
    """
    Validate and sanitize output path to prevent path traversal attacks.

    The output is restricted to the temp/copilot-review/ directory within
    the current working directory.

    Args:
        output_path: User-provided output file path

    Returns:
        Validated Path object

    Raises:
        ValueError: If path attempts directory traversal or is invalid
    """
    safe_filename = os.path.normpath(output_path)

    if safe_filename.startswith("..") or "/../" in safe_filename or "\\..\\" in safe_filename:
        raise ValueError(f"Invalid output path: directory traversal not allowed ({output_path})")

    safe_filename = safe_filename.lstrip("/\\")

    base_dir = Path.cwd() / "temp" / "copilot-review"
    full_path = base_dir / safe_filename

    try:
        full_path = full_path.resolve()
        base_dir_resolved = base_dir.resolve()

        if not str(full_path).startswith(str(base_dir_resolved)):
            raise ValueError(f"Invalid output path: must be within temp/copilot-review/ ({output_path})")

        return full_path
    except (OSError, ValueError) as e:
        raise ValueError(f"Invalid output path: {e}")


def is_copilot_review(review: Dict[str, Any]) -> bool:
    """
    Determine if a review is from GitHub Copilot.

    Copilot reviews are identified by:
    - user.type == "Bot"
    - user.login contains "copilot" (case-insensitive)
    - user.login contains "[bot]" (GitHub App bot pattern)

    Args:
        review: Review object from GitHub API

    Returns:
        True if review is from Copilot, False otherwise
    """
    user = review.get("user", {})
    user_type = user.get("type", "")
    login = user.get("login", "").lower()

    return user_type == "Bot" or "copilot" in login or "[bot]" in login


def main():
    parser = argparse.ArgumentParser(
        description="Fetch GitHub Copilot pull request reviews",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Fetch by URL:
    python fetch_copilot_reviews.py --pr https://github.com/owner/repo/pull/123

  Fetch by number:
    python fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO

  Save to file (saved to temp/copilot-review/reviews.json):
    python fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --output reviews.json

  Use custom token:
    python fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --token ghp_XXX

Environment Variables:
  GITHUB_TOKEN: GitHub authentication token (default authentication method)
        """,
    )

    parser.add_argument(
        "--pr",
        required=True,
        help="Pull request number or full GitHub PR URL (e.g., https://github.com/owner/repo/pull/123)",
    )

    parser.add_argument("--owner", help="Repository owner (required when --pr is a number)")

    parser.add_argument("--repo", help="Repository name (required when --pr is a number)")

    parser.add_argument("--token", default=None, help="GitHub token (default: GITHUB_TOKEN env var)")

    parser.add_argument(
        "--output",
        "-o",
        default=None,
        help="Output filename (saved to temp/copilot-review/, default: stdout)",
    )

    args = parser.parse_args()

    use_gh_cli = check_gh_cli()
    token = args.token or os.environ.get("GITHUB_TOKEN")

    if args.token or token:
        use_gh_cli = False

    if not use_gh_cli and not token:
        print(
            "Error: gh CLI not available/authenticated and GitHub token not provided. Run 'gh auth login' or use --token / set GITHUB_TOKEN env var.",
            file=sys.stderr,
        )
        sys.exit(1)

    owner, repo, pr_number = parse_pr_url(args.pr)

    if pr_number:
        if args.owner or args.repo:
            print("Warning: --owner and --repo ignored when --pr is a URL", file=sys.stderr)
    else:
        pr_number = int(args.pr)
        if not args.owner or not args.repo:
            print(
                "Error: --owner and --repo are required when --pr is a number",
                file=sys.stderr,
            )
            sys.exit(1)
        owner = args.owner
        repo = args.repo

    assert isinstance(owner, str) and isinstance(repo, str) and isinstance(pr_number, int)

    print(f"Fetching reviews for {owner}/{repo} pull request #{pr_number}...", file=sys.stderr)

    try:
        reviews = fetch_reviews(owner, repo, pr_number, use_gh_cli, token)
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    copilot_reviews = []

    for review in reviews:
        if is_copilot_review(review):
            review_id = review.get("id")
            if review_id is None:
                continue
            comments = fetch_review_comments(owner, repo, pr_number, review_id, use_gh_cli, token)

            copilot_reviews.append(
                {
                    "id": review.get("id"),
                    "user": {
                        "login": review.get("user", {}).get("login"),
                        "type": review.get("user", {}).get("type"),
                        "avatar_url": review.get("user", {}).get("avatar_url"),
                    },
                    "state": review.get("state"),
                    "body": review.get("body"),
                    "submitted_at": review.get("submitted_at"),
                    "html_url": review.get("html_url"),
                    "comments": [
                        {
                            "id": comment.get("id"),
                            "body": comment.get("body"),
                            "path": comment.get("path"),
                            "line": comment.get("line"),
                            "diff_hunk": comment.get("diff_hunk"),
                        }
                        for comment in comments
                    ],
                }
            )

    output = {
        "pr": {
            "owner": owner,
            "repo": repo,
            "pull_number": pr_number,
            "url": f"https://github.com/{owner}/{repo}/pull/{pr_number}",
        },
        "copilot_reviews": copilot_reviews,
        "total_reviews": len(reviews),
        "copilot_count": len(copilot_reviews),
    }

    json_output = json.dumps(output, indent=2)

    if args.output:
        try:
            output_path = validate_output_path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(json_output)
            print(f"Output saved to {output_path}", file=sys.stderr)
        except ValueError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(json_output)

    print(f"\nFound {len(copilot_reviews)} Copilot review(s) out of {len(reviews)} total review(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
