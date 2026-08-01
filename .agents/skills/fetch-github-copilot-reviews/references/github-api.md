# GitHub API Reference for Pull Request Reviews

This document provides reference information for GitHub REST API endpoints used to fetch pull request reviews and comments.

## Endpoints

### List Reviews for a Pull Request

Fetch all reviews for a specified pull request.

**Endpoint:**
```
GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews
```

**Path Parameters:**
- `owner` (string, required): The account owner of the repository
- `repo` (string, required): The name of the repository
- `pull_number` (integer, required): The pull request number

**Headers:**
- `Accept`: Recommended: `application/vnd.github+json`
- `Authorization`: Bearer token with `repo` scope
- `X-GitHub-Api-Version`: Recommended: `2022-11-28`

**Example:**
```bash
curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer YOUR-TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews
```

**Response Schema:**
```json
[
  {
    "id": 80,
    "node_id": "MDE3OlB1bGxSZXF1ZXN0UmV2aWV3ODA=",
    "user": {
      "login": "octocat",
      "id": 1,
      "node_id": "MDQ6VXNlcjE=",
      "avatar_url": "https://github.com/images/error/octocat_happy.gif",
      "gravatar_id": "",
      "url": "https://api.github.com/users/octocat",
      "html_url": "https://github.com/octocat",
      "type": "User",
      "site_admin": false
    },
    "body": "Here is the body for the review.",
    "state": "APPROVED",
    "html_url": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80",
    "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/12",
    "_links": {
      "html": {
        "href": "https://github.com/octocat/Hello-World/pull/12#pullrequestreview-80"
      },
      "pull_request": {
        "href": "https://github.com/octocat/Hello-World/pulls/12"
      }
    },
    "submitted_at": "2019-11-17T17:43:43Z",
    "commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091",
    "author_association": "COLLABORATOR"
  }
]
```

**Review States:**
- `APPROVED`: Review approves the changes
- `CHANGES_REQUESTED`: Review requests changes
- `COMMENTED`: Review contains only comments (no approval or request)
- `PENDING`: Review is pending submission
- `DISMISSED`: Review has been dismissed

### List Comments for a Review

Fetch all review comments for a specific pull request review.

**Endpoint:**
```
GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/comments
```

**Path Parameters:**
- `owner` (string, required): The account owner of the repository
- `repo` (string, required): The name of the repository
- `pull_number` (integer, required): The pull request number
- `review_id` (integer, required): The unique identifier of the review

**Headers:**
- `Accept`: Recommended: `application/vnd.github+json`
- `Authorization`: Bearer token with `repo` scope
- `X-GitHub-Api-Version`: Recommended: `2022-11-28`

**Example:**
```bash
curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer YOUR-TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/OWNER/REPO/pulls/PULL_NUMBER/reviews/REVIEW_ID/comments
```

**Response Schema:**
```json
[
  {
    "id": 10,
    "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw",
    "pull_request_review_id": 42,
    "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...",
    "path": "file1.txt",
    "position": 1,
    "original_position": 4,
    "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
    "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840",
    "in_reply_to_id": 8,
    "user": {
      "login": "octocat",
      "id": 1,
      "avatar_url": "https://github.com/images/error/octocat_happy.gif",
      "url": "https://api.github.com/users/octocat"
    },
    "body": "Great stuff!",
    "created_at": "2011-04-14T16:00:49Z",
    "updated_at": "2011-04-14T16:00:49Z",
    "html_url": "https://github.com/octocat/Hello-World/pull/1#discussion-diff-1",
    "pull_request_url": "https://api.github.com/repos/octocat/Hello-World/pulls/1",
    "author_association": "NONE",
    "start_line": 1,
    "original_start_line": 1,
    "start_side": "RIGHT",
    "line": 2,
    "original_line": 2,
    "side": "RIGHT"
  }
]
```

## Copilot Identification Patterns

GitHub Copilot reviews can be identified using the following patterns in the review `user` object:

### 1. User Type
```json
{
  "type": "Bot"
}
```
GitHub App bots (including Copilot) have `type: "Bot"` in their user object, while regular users have `type: "User"`.

### 2. Login Name Patterns

**GitHub App Bot Pattern:**
```json
{
  "login": "app-name[bot]"
}
```
GitHub App bots have a `[bot]` suffix. Examples:
- `github-actions[bot]`
- `dependabot[bot]`
- `copilot[bot]` (hypothetical)

**Copilot-Specific Pattern:**
```json
{
  "login": "github-copilot"
}
```
Copilot-related bot accounts may contain "copilot" in their login name.

### 3. Review Content
```json
{
  "body": "@copilot This is an automated review..."
}
```
Reviews that mention `@copilot` may be Copilot-generated.

### Filtering Logic
```javascript
function isCopilotReview(review) {
  const user = review.user || {};
  const userType = user.type || "";
  const login = (user.login || "").toLowerCase();
  const body = (review.body || "").toLowerCase();

  // Check if user is a bot
  if (userType === "Bot") {
    return true;
  }

  // Check if login contains "copilot"
  if (login.includes("copilot")) {
    return true;
  }

  // Check if login has GitHub App bot suffix
  if (login.includes("[bot]")) {
    return true;
  }

  // Check if review body mentions copilot
  if (body.includes("@copilot")) {
    return true;
  }

  return false;
}
```

## Authentication

### Personal Access Token (PAT)

Create a PAT at: GitHub Settings → Developer Settings → Personal access tokens

**Required Scopes:**
- `repo`: For private repositories (recommended)
- `public_repo`: For public repositories only

**Usage:**
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxx"
# Or pass as header: Authorization: Bearer ghp_xxxxxxxxxxxxxxxxx
```

### Environment Variables

The script supports the `GITHUB_TOKEN` environment variable:
```bash
export GITHUB_TOKEN="your-token-here"
python fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
```

Or pass via command line:
```bash
python fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --token "your-token-here"
```

## Rate Limiting

GitHub API has rate limits to prevent abuse:

| Authentication | Requests per Hour |
|----------------|-------------------|
| Authenticated | 5,000 |
| Unauthenticated | 60 |

### Rate Limit Headers

Responses include these headers:
- `X-RateLimit-Limit`: Total requests allowed
- `X-RateLimit-Remaining`: Requests remaining
- `X-RateLimit-Reset`: Unix timestamp when limit resets
- `X-RateLimit-Used`: Requests used

### Handling Rate Limits

If you receive a 403 Forbidden response with rate limit exceeded:
```bash
# Check rate limit status
curl -I -H "Authorization: Bearer TOKEN" https://api.github.com/repos/owner/repo/pulls/1/reviews

# Output:
# X-RateLimit-Limit: 5000
# X-RateLimit-Remaining: 4999
# X-RateLimit-Reset: 1672531200
# X-RateLimit-Used: 1
```

## Error Codes

| Code | Meaning | Action |
|------|---------|--------|
| `200 OK` | Success | Process response |
| `401 Unauthorized` | Invalid or missing token | Check token validity |
| `403 Forbidden` | Rate limit exceeded or insufficient permissions | Check rate limit or permissions |
| `404 Not Found` | PR, owner, or repo doesn't exist | Verify input values |
| `422 Unprocessable Entity` | Invalid input | Check request format |
| `500+ Server Error` | GitHub service issue | Retry later |

## Common Issues

### Token Permission Denied
```
Error: 403 Forbidden - Resource not accessible by integration
```
**Solution**: Ensure your PAT has the `repo` scope or the GitHub App has repository access.

### Rate Limit Exceeded
```
Error: 403 Forbidden - API rate limit exceeded
```
**Solution**: Wait until `X-RateLimit-Reset` timestamp, or use authenticated requests.

### PR Not Found
```
Error: 404 Not Found - Pull request not found
```
**Solution**: Verify the owner, repo name, and PR number are correct.
