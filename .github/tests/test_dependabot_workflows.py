"""Exercise the actual workflow shell guards without GitHub credentials or writes."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

import yaml


GITHUB_DIRECTORY = Path(__file__).resolve().parents[1]
AUTO_MERGE_WORKFLOW = yaml.safe_load(
    (GITHUB_DIRECTORY / "workflows/dependabot-auto-merge.yml").read_text()
)
SECURITY_WORKFLOW = yaml.safe_load(
    (GITHUB_DIRECTORY / "workflows/security-scan.yml").read_text()
)
AUTO_MERGE_JOB = AUTO_MERGE_WORKFLOW["jobs"]["dependabot-auto-merge"]


def dependabot_commit_fixture(sha="event-head", author="dependabot[bot]", verified=True):
    """Return the API fields used for Dependabot commit signature validation."""
    return {
        "sha": sha,
        "author": {"login": author},
        "commit": {"verification": {"verified": verified}},
    }


def required_ci_rule_fixture(context="dependency-update-ci", app_id=15368, strict=True):
    """Return an active branch rule binding required CI to the GitHub Actions App."""
    return [{
        "type": "required_status_checks",
        "parameters": {
            "strict_required_status_checks_policy": strict,
            "required_status_checks": [{"context": context, "integration_id": app_id}],
        },
    }]


class DependabotWorkflowTests(unittest.TestCase):
    def run_workflow_guard(self, step_index, *, commits=None, rules=None, api_failure=False):
        """Run the unchanged workflow shell with an isolated, fixture-only gh binary."""
        with tempfile.TemporaryDirectory() as directory:
            gh = Path(directory) / "gh"
            gh.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "args = sys.argv[1:]\n"
                "if args[0] == 'api':\n"
                "    if os.environ['API_FAILURE'] == '1': sys.exit(1)\n"
                "    key = 'COMMITS' if args[-1].endswith('/commits') else 'RULES'\n"
                "    print(os.environ[key])\n"
                "elif args[:2] == ['pr', 'merge']:\n"
                "    print('MERGE ' + json.dumps(args))\n"
                "else:\n"
                "    sys.exit('Unexpected gh command: ' + repr(args))\n"
            )
            gh.chmod(0o755)
            env = {
                **os.environ,
                "PATH": directory + os.pathsep + os.environ["PATH"],
                "RUNNER_TEMP": directory,
                "GH_TOKEN": "test-token-not-a-credential",
                "GH_REPO": "owner/repo",
                "PR_NUMBER": "42",
                "PR_HEAD_SHA": "event-head",
                "BASE_BRANCH": "main",
                "COMMITS": json.dumps(commits),
                "RULES": json.dumps(rules),
                "API_FAILURE": "1" if api_failure else "0",
            }
            return subprocess.run(
                ["bash", "-c", AUTO_MERGE_JOB["steps"][step_index]["run"]],
                env=env, capture_output=True, text=True, check=False,
            )

    def test_every_commit_page_is_verified(self):
        result = self.run_workflow_guard(0, commits=[
            [dependabot_commit_fixture("first-head")], [dependabot_commit_fixture()],
        ])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_empty_unsigned_foreign_and_stale_commits_are_rejected(self):
        cases = [
            [], [[]],
            [[dependabot_commit_fixture(verified=False)]],
            [[dependabot_commit_fixture(author="contributor")]],
            [[dependabot_commit_fixture("newer-head")]],
            [[dependabot_commit_fixture("first-head")],
             [dependabot_commit_fixture(author="contributor")]],
        ]
        for commits in cases:
            with self.subTest(commits=commits):
                result = self.run_workflow_guard(0, commits=commits)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("MERGE ", result.stdout)

    def test_only_patch_and_minor_are_allowlisted(self):
        condition = AUTO_MERGE_JOB["steps"][2]["if"]
        self.assertEqual(
            re.findall(r"steps\.metadata\.outputs\.update-type == '([^']+)'", condition),
            ["version-update:semver-patch", "version-update:semver-minor"],
        )
        self.assertNotIn("!=", condition)

    def test_ci_rule_enables_merge_with_head_pinning_without_bypass(self):
        result = self.run_workflow_guard(2, rules=required_ci_rule_fixture())
        self.assertEqual(result.returncode, 0, result.stderr)
        merge_line = next(line for line in result.stdout.splitlines() if line.startswith("MERGE "))
        self.assertEqual(json.loads(merge_line.removeprefix("MERGE ")), [
            "pr", "merge", "42", "--repo", "owner/repo", "--auto", "--squash",
            "--match-head-commit", "event-head",
        ])

    def test_checked_in_ruleset_enforces_the_expected_gate_without_bypass(self):
        ruleset = json.loads((GITHUB_DIRECTORY / "rulesets/dependency-update-ci.json").read_text())
        self.assertEqual(ruleset["enforcement"], "active")
        self.assertEqual(ruleset["bypass_actors"], [])
        self.assertEqual(ruleset["conditions"]["ref_name"]["include"], ["refs/heads/main"])
        result = self.run_workflow_guard(2, rules=ruleset["rules"])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_or_weakened_ci_rules_never_merge(self):
        for rules in [
            [], required_ci_rule_fixture(context="unrelated-check"),
            required_ci_rule_fixture(app_id=None), required_ci_rule_fixture(app_id=123),
            required_ci_rule_fixture(strict=False),
        ]:
            with self.subTest(rules=rules):
                result = self.run_workflow_guard(2, rules=rules)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("MERGE ", result.stdout)

    def test_api_errors_fail_closed(self):
        for step in [0, 2]:
            with self.subTest(step=step):
                result = self.run_workflow_guard(step, api_failure=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("MERGE ", result.stdout)

    def test_privileged_workflow_has_no_checkout_or_unverified_metadata(self):
        self.assertEqual(AUTO_MERGE_WORKFLOW["permissions"], {})
        condition = AUTO_MERGE_JOB["if"]
        for guard in [
            "github.event.repository.owner.type == 'User'",
            "github.event.pull_request.user.login == 'dependabot[bot]'",
            "github.event.pull_request.head.repo.full_name == github.repository",
            "github.event.pull_request.base.repo.full_name == github.repository",
            "!github.event.pull_request.draft",
        ]:
            self.assertIn(guard, condition)
        actions = [step["uses"] for step in AUTO_MERGE_JOB["steps"] if "uses" in step]
        self.assertEqual(len(actions), 1)
        self.assertRegex(actions[0], r"^dependabot/fetch-metadata@[0-9a-f]{40}$")
        self.assertEqual(set(AUTO_MERGE_JOB["steps"][1]["with"]), {"github-token"})

    def test_ci_is_read_only_and_runs_for_dependabot(self):
        self.assertEqual(SECURITY_WORKFLOW["permissions"], {})
        gate = SECURITY_WORKFLOW["jobs"]["dependency-update-ci"]
        self.assertEqual(gate["if"], "always()")
        self.assertEqual(set(gate["needs"]), {
            "gitleaks", "semgrep", "zizmor", "dependency-validation",
        })
        for job in SECURITY_WORKFLOW["jobs"].values():
            self.assertNotIn("dependabot[bot]", job.get("if", ""))
            self.assertNotIn("write", job.get("permissions", {}).values())

    def test_ci_gate_rejects_failed_cancelled_and_skipped_checks(self):
        gate = SECURITY_WORKFLOW["jobs"]["dependency-update-ci"]
        for outcome in ["success", "failure", "cancelled", "skipped"]:
            with self.subTest(outcome=outcome):
                results = {name: {"result": "success"} for name in gate["needs"]}
                results["semgrep"]["result"] = outcome
                result = subprocess.run(
                    ["bash", "-c", gate["steps"][0]["run"]],
                    env={**os.environ, "CHECK_RESULTS": json.dumps(results)},
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode == 0, outcome == "success")

    def test_major_updates_are_not_ignored(self):
        dependabot = yaml.safe_load((GITHUB_DIRECTORY / "dependabot.yml").read_text())
        self.assertEqual({entry["package-ecosystem"] for entry in dependabot["updates"]}, {
            "bun", "uv", "github-actions", "docker", "pre-commit",
        })
        for entry in dependabot["updates"]:
            self.assertNotIn("ignore", entry)


if __name__ == "__main__":
    unittest.main()
