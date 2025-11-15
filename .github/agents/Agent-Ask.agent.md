---
description: 'Agent機能を維持しつつ、ファイルを修正しない'
tools: ['runCommands', 'runTasks', 'runNotebooks', 'search', 'new', 'github/github-mcp-server/get_commit', 'github/github-mcp-server/get_file_contents', 'github/github-mcp-server/get_label', 'github/github-mcp-server/get_latest_release', 'github/github-mcp-server/get_release_by_tag', 'github/github-mcp-server/issue_read', 'github/github-mcp-server/list_branches', 'github/github-mcp-server/list_commits', 'github/github-mcp-server/list_issue_types', 'github/github-mcp-server/list_issues', 'github/github-mcp-server/list_pull_requests', 'github/github-mcp-server/list_tags', 'github/github-mcp-server/pull_request_read', 'github/github-mcp-server/search_code', 'github/github-mcp-server/search_issues', 'github/github-mcp-server/search_pull_requests', 'github/github-mcp-server/search_repositories', 'github/github-mcp-server/search_users', 'extensions', 'usages', 'vscodeAPI', 'problems', 'changes', 'testFailure', 'openSimpleBrowser', 'fetch', 'githubRepo', 'github.vscode-pull-request-github/copilotCodingAgent', 'github.vscode-pull-request-github/issue_fetch', 'github.vscode-pull-request-github/suggest-fix', 'github.vscode-pull-request-github/searchSyntax', 'github.vscode-pull-request-github/doSearch', 'github.vscode-pull-request-github/renderIssues', 'github.vscode-pull-request-github/activePullRequest', 'github.vscode-pull-request-github/openPullRequest', 'todos', 'runSubagent']
model: Claude Sonnet 4.5
name: "Agent-Ask"
---

ユーザーから指示された内容を遂行すること。但し、ファイルに変更を加えることを禁止する。
