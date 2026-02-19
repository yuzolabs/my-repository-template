# Test Plan for GitHub Copilot Reviews Skill

## Overview

This document outlines test cases for verifying the functionality of the `fetch_copilot_reviews.py` script.

## Test Environment

- Python 3.11+
- GitHub Personal Access Token with `repo` scope
- Test repository with public pull requests

## Unit Tests

### URL Parsing Tests

**Test 1: Parse Full GitHub PR URL**
```bash
# Input: Full GitHub URL
python -c "from fetch_copilot_reviews import parse_pr_url; print(parse_pr_url('https://github.com/cli/cli/pull/5788'))"
# Expected Output: ('cli', 'cli', 5788)
```

**Test 2: Parse URL with www Subdomain**
```bash
# Input: URL with www
python -c "from fetch_copilot_reviews import parse_pr_url; print(parse_pr_url('https://www.github.com/owner/repo/pull/123'))"
# Expected Output: ('owner', 'repo', 123)
```

**Test 3: Parse Non-URL Input**
```bash
# Input: Plain number
python -c "from fetch_copilot_reviews import parse_pr_url; print(parse_pr_url('123'))"
# Expected Output: (None, None, None)
```

### Copilot Detection Tests

**Test 1: Bot Type Detection**
```python
from fetch_copilot_reviews import is_copilot_review

review = {
    "user": {
        "type": "Bot",
        "login": "github-actions[bot]"
    },
    "body": "This is a review"
}

assert is_copilot_review(review) == True
```

**Test 2: Copilot Login Detection**
```python
review = {
    "user": {
        "type": "User",
        "login": "github-copilot"
    },
    "body": "This is a review"
}

assert is_copilot_review(review) == True
```

**Test 3: Bot Suffix Detection**
```python
review = {
    "user": {
        "type": "User",
        "login": "dependabot[bot]"
    },
    "body": "This is a review"
}

assert is_copilot_review(review) == True
```

**Test 4: Regular User Not Detected**
```python
review = {
    "user": {
        "type": "User",
        "login": "octocat"
    },
    "body": "This is a review"
}

assert is_copilot_review(review) == False
```

## Integration Tests

### API Authentication Tests

**Test 1: Valid Token**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
# Expected: Fetches reviews successfully, outputs JSON
```

**Test 2: Missing Token**
```bash
unset GITHUB_TOKEN
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --token ""
# Expected: Error message "GitHub token not provided", exit code 1
```

**Test 3: Invalid Token**
```bash
export GITHUB_TOKEN="invalid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
# Expected: Error message "Unauthorized. Check your GitHub token.", exit code 1
```

### PR Fetching Tests

**Test 1: Fetch by Number**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner cli --repo cli
# Expected: Fetches PR #123 from cli/cli, outputs JSON
```

**Test 2: Fetch by URL**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr https://github.com/cli/cli/pull/5788
# Expected: Fetches PR #5788 from cli/cli, outputs JSON
```

**Test 3: Non-Existent PR**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 999999999 --owner cli --repo cli
# Expected: Error message "Not Found. PR 999999999 not found in cli/cli.", exit code 1
```

**Test 4: Non-Existent Repository**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner nonexistentowner --repo nonexistentrepo
# Expected: Error message "Not Found. PR 123 not found in nonexistentowner/nonexistentrepo.", exit code 1
```

### Output Format Tests

**Test 1: JSON Output to stdout**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
# Expected: Valid JSON printed to stdout
```

**Test 2: JSON Output to File**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --output output.json
# Expected: output.json created with valid JSON, message "Output saved to output.json"
```

**Test 3: Output Schema Verification**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO --output output.json
python -c "import json; data = json.load(open('output.json')); assert 'pr' in data; assert 'copilot_reviews' in data; assert 'total_reviews' in data; assert 'copilot_count' in data"
# Expected: No assertion errors
```

### Copilot Filtering Tests

**Test 1: Filter Bot Reviews**
```bash
# Use a PR that has bot reviews
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
# Expected: copilot_reviews array contains only reviews with user.type == "Bot" or login containing "copilot"/"[bot]"
```

**Test 2: Filter with Case-Insensitive Login**
```bash
# Test case-insensitive login matching
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
# Expected: Reviews with "Copilot", "COPILOT", or "copilot" in login are included
```

## Error Handling Tests

### HTTP Error Tests

**Test 1: Handle 401 Unauthorized**
```bash
export GITHUB_TOKEN="invalid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
# Expected: Error message "Unauthorized. Check your GitHub token.", exit code 1
```

**Test 2: Handle 404 Not Found**
```bash
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 999999999 --owner OWNER --repo REPO
# Expected: Error message "Not Found. PR 999999999 not found in OWNER/REPO.", exit code 1
```

**Test 3: Handle 403 Forbidden (Rate Limit)**
```bash
# Trigger rate limit by making many requests (or mock this)
export GITHUB_TOKEN="valid-token"
python scripts/fetch_copilot_reviews.py --pr 123 --owner OWNER --repo REPO
# Expected: Error message about rate limit or permissions, exit code 1
```

### Network Error Tests

**Test 1: Handle Connection Error**
```bash
# Disable internet connection or use unreachable endpoint
export GITHUB_TOKEN="valid-token"
# Mock network error or use invalid endpoint
# Expected: Error message "Network Error: [reason]", exit code 1
```

## Manual Test Checklist

### Pre-Test Setup

- [ ] GitHub Personal Access Token created with `repo` scope
- [ ] Test repository selected with PRs
- [ ] GITHUB_TOKEN environment variable set

### Script Functionality

- [ ] Script runs without syntax errors: `python scripts/fetch_copilot_reviews.py --help`
- [ ] Help output is readable and complete
- [ ] Script accepts PR number with owner/repo
- [ ] Script accepts full GitHub PR URL
- [ ] Script outputs valid JSON
- [ ] JSON contains all required fields: pr, copilot_reviews, total_reviews, copilot_count

### Copilot Identification

- [ ] Bot reviews are correctly identified (user.type == "Bot")
- [ ] Copilot reviews are correctly identified (login contains "copilot")
- [ ] GitHub App bot reviews are correctly identified (login contains "[bot]")
- [ ] Regular user reviews are not incorrectly flagged as Copilot

### Output Format

- [ ] JSON is properly formatted (can be parsed by json.load)
- [ ] PR info is correct (owner, repo, pull_number, url)
- [ ] copilot_reviews array contains review objects with id, user, body, state
- [ ] Review comments are included in each review
- [ ] total_reviews matches actual review count
- [ ] copilot_count matches filtered review count

### Real PR Verification

- [ ] Test with real PR that has Copilot reviews
- [ ] Verify Copilot reviews are correctly fetched
- [ ] Verify review body is included
- [ ] Verify inline comments are included
- [ ] Verify HTML URLs are correct

## Success Criteria

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Script handles all error cases gracefully
- [ ] Output JSON is valid and matches schema
- [ ] Copilot identification is accurate
- [ ] Manual testing confirms real PR fetching works

## Notes

- Some tests may require mocking GitHub API responses
- Rate limit tests may be difficult to trigger without automation
- Real PR verification requires a repository with Copilot reviews
