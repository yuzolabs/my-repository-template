---
name: fetch-github-copilot-reviews
description: Fetch GitHub Copilot pull request reviews programmatically. Use when Agents needs to retrieve Copilot-generated PR reviews from GitHub, including review body, inline comments, and metadata. Supports PR numbers or full URLs, filters for Copilot reviews using bot detection patterns, and outputs structured JSON.
---

# GitHub Copilot Reviews

## Overview

Fetch GitHub Copilot pull request reviews from GitHub repositories. This skill retrieves PR reviews, filters for Copilot-generated reviews, and returns structured JSON with review content and inline comments.

## Quick Start

```bash
# Set GitHub token
export GITHUB_TOKEN="your-token-here"

# Fetch Copilot reviews by PR URL
python scripts/fetch_copilot_reviews.py --pr https://github.com/owner/repo/pull/123

# Fetch by PR number
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO

# Save to file
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --output reviews.json
```

## Usage Examples

### Basic Usage

**Fetch Copilot reviews by URL:**
```bash
python scripts/fetch_copilot_reviews.py --pr https://github.com/cli/cli/pull/123
```

**Fetch by PR number with owner/repo:**
```bash
python scripts/fetch_copilot_reviews.py --pr 5788 --owner cli --repo cli
```

**Save output to file (saved to temp/copilot-review/output.json):**
```bash
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --output output.json
```

### Use with GITHUB_TOKEN Environment Variable

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
```

### Use Custom Token

```bash
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --token "your-token-here"
```

## Command Reference

### `--pr` (Required)

Pull request number or full GitHub PR URL.

**Examples:**
- `--pr 123`: PR number
- `--pr https://github.com/owner/repo/pull/123`: Full URL

### `--owner` (Required when PR is a number)

Repository owner username.

**Example:**
- `--owner cli`

### `--repo` (Required when PR is a number)

Repository name.

**Example:**
- `--repo cli`

### `--token` (Optional)

GitHub authentication token. Defaults to `GITHUB_TOKEN` environment variable.

**Example:**
- `--token "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"`

### `--output` (Optional)

Output filename. The file is saved to `temp/copilot-review/` directory within the current working directory. Defaults to stdout.

**Example:**
- `--output reviews.json` (saved to `temp/copilot-review/reviews.json`)

## Authentication Setup

### Create Personal Access Token

1. Go to GitHub Settings → Developer Settings → Personal access tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (recommended) or `public_repo` (public repos only)
4. Generate and copy the token

### Set Environment Variable

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

Or pass token via command line:
```bash
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --token "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## Output Format

The script outputs JSON with the following structure:

```json
{
  "pr": {
    "owner": "cli",
    "repo": "cli",
    "pull_number": 5788,
    "url": "https://github.com/cli/cli/pull/5788"
  },
  "copilot_reviews": [
    {
      "id": 80,
      "user": {
        "login": "github-copilot",
        "type": "Bot",
        "avatar_url": "https://avatars.githubusercontent.com/u/..."
      },
      "state": "APPROVED",
      "body": "Here is my review...",
      "submitted_at": "2024-01-15T10:30:00Z",
      "html_url": "https://github.com/owner/repo/pull/123#pullrequestreview-80",
      "comments": [
        {
          "id": 10,
          "body": "Consider renaming this variable...",
          "path": "src/main.py",
          "line": 42,
          "diff_hunk": "@@ -40,6 +40,7 @@ def process_data():"
        }
      ]
    }
  ],
  "total_reviews": 5,
  "copilot_count": 2
}
```

## Copilot Identification

Copilot reviews are identified using multiple patterns:

1. **User Type**: `user.type == "Bot"` - GitHub App bots have type "Bot"
2. **Login Name**: `user.login` contains "copilot" (case-insensitive)
3. **Bot Suffix**: `user.login` contains "[bot]" - GitHub App bot pattern

These patterns are combined with OR logic for robust identification.

## Error Handling

The script handles common errors:

| Error | Message | Solution |
|-------|---------|----------|
| `401 Unauthorized` | Invalid or missing token | Check `GITHUB_TOKEN` or `--token` |
| `403 Forbidden` | Rate limit exceeded | Wait and retry with authenticated request |
| `404 Not Found` | PR/owner/repo doesn't exist | Verify owner, repo, and PR number |
| Network Error | Connection failed | Check internet connection |

## Rate Limiting

GitHub API rate limits:
- Authenticated: 5,000 requests per hour
- Unauthenticated: 60 requests per hour

Check rate limit status:
```bash
curl -I -H "Authorization: Bearer TOKEN" https://api.github.com/repos/owner/repo/pulls/1/reviews
```

## Resources

### scripts/

**fetch_copilot_reviews.py**: Main script that:
- Parses PR URLs and extracts owner/repo/PR number
- Fetches reviews from GitHub REST API
- Filters for Copilot reviews using bot detection patterns
- Fetches inline comments for each Copilot review
- Outputs structured JSON

### references/

**github-api.md**: Complete GitHub API reference including:
- PR reviews endpoint documentation
- Review comments endpoint documentation
- Copilot identification patterns
- Authentication methods
- Rate limiting information
- Error code reference

### assets/

This skill does not require asset files.
