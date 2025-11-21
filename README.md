# Gitleaks Local Git Pre-Commit Hook Setup

## Introduction

Gitleaks is an open-source security tool that scans code repositories to detect sensitive information, such as API keys, passwords, and private keys, which may have been accidentally committed to version control.

This script automates the setup of a global pre-commit hook to automatically scan your code, using Gitleaks, for potential secrets *before* every commit.

## Installation

Run this helper script in any bash shell (Windows/Linux/Mac).

```bash
curl -sSL https://raw.githubusercontent.com/AmedeoV/gitleaks-pre-commit-hook/refs/heads/main/gitleaks-local-git-pre-hook.sh | bash
```

## Testing the Setup

To test the precommit hook, you can attempt to commit a change with a fake secret. Try this in an existing git repository:

```bash
echo 'slack_token=xoxb-1234567890-1234567890123-AbCdEfGh1234567890123456' > fake_secret.txt
git add fake_secret.txt
git commit -m "Add fake secret for testing"
```

Gitleaks should detect the fake secret, and the pre-commit hook will block the commit. You will see an error message similar to:

```
Finding:     xoxb-1234567890-1234567890123-AbCdEfGh1234567890123456
Secret:      xoxb-1234567890-1234567890123-AbCdEfGh1234567890123456
RuleID:      slack-bot-token
Entropy:     4.151122
File:        fake_secret.txt
Line:        1
Fingerprint: fake_secret.txt:slack-bot-token:1

0 commits scanned.
scanned ~55 bytes (55 bytes)
leaks found: 1
```

This confirms that the pre-commit hook is working. Remember to remove the fake secret after testing:

```bash
rm fake_secret.txt
```

### Bypassing the Pre-Commit Hook

In cases where Gitleaks might flag a false positive, or if you explicitly need to bypass the pre-commit hook for a specific commit, you can use the `--no-verify` flag:

```
git commit -m "Commit message" --no-verify
```

Use this option with caution and only when you are certain that the changes do not contain actual sensitive information.

**For Rider Users:**

If you are using JetBrains Rider to commit your code and wish to bypass Git commit hooks, you will need to configure this within Rider's settings:

1.  Go to `File` > `Settings` (or `Rider` > `Preferences` on macOS).
2.  Scroll down to the bottom of the `Advanced Settings` pane.
3.  You will find an option titled "Do not run Git commit hooks" (or similar). Check this box to disable hooks for your commits made through Rider.

![rider-no-verify.png](rider-no-verify.png)

## Additional information


### Handling Unverified/Unknown Issues

The pre-commit hook is configured to **fail the commit for any secrets** detected by Gitleaks, as a failsafe approach. The intention is to ensure the committer reviews any findings before proceeding.

### Gitleaks configuration

By default, this setup uses Gitleaks' comprehensive built-in rules which detect 100+ types of secrets including AWS keys, GitHub tokens, Slack tokens, private keys, and many more.

#### Adding Custom Rules

To add or modify custom detection rules, edit `~/.gitleaks-custom-rules.toml`.

**Example: Adding a new rule**

Add this to `~/.gitleaks-custom-rules.toml`:

```toml
[[rules]]
id = "my-custom-secret"
description = "Detects my custom secret pattern"
regex = '''your-regex-pattern-here'''
tags = ["custom", "secret"]

[[rules.Entropies]]
Min = "3.0"
Max = "8"
```

Then re-run the installation script to apply the changes to all repositories.