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

### Updating Gitleaks

To update Gitleaks to the latest version, simply re-run the installation script:

```bash
curl -sSL https://raw.githubusercontent.com/AmedeoV/gitleaks-pre-commit-hook/refs/heads/main/gitleaks-local-git-pre-hook.sh | bash
```

Alternatively, you can update manually based on your OS:

**macOS (Homebrew):**
```bash
brew upgrade gitleaks
```

**Linux/Windows (using the installation script):**
```bash
curl -sSfL https://raw.githubusercontent.com/gitleaks/gitleaks/master/scripts/install.sh | sh -s -- -b ~/.local/bin
```

You can check your current version with:
```bash
gitleaks version
```

### Handling Unverified/Unknown Issues

The pre-commit hook is configured to **fail the commit for any secrets** detected by Gitleaks, as a failsafe approach. The intention is to ensure the committer reviews any findings before proceeding.

### Gitleaks configuration

By default, this setup uses Gitleaks' comprehensive built-in rules which detect 100+ types of secrets including AWS keys, GitHub tokens, Slack tokens, private keys, and many more.

#### Global Custom Configuration

The installer now uses a single user-maintained file: **`~/.gitleaks-custom-rules.toml`**.

Gitleaks runs with its built‑in default rules plus any custom rules you define in that file. The previously generated `~/.gitleaks.toml` aggregation file is no longer required and is considered legacy. If it exists it will still be honored, but you do not need to create or manage it.

Because the hook uses global configuration, **you don't need to copy any configuration files into individual repositories**.

#### Adding / Editing Custom Rules

Edit `~/.gitleaks-custom-rules.toml` to add or adjust patterns:

```bash
# Linux/Mac/WSL
nano ~/.gitleaks-custom-rules.toml

# Windows PowerShell
notepad $HOME\.gitleaks-custom-rules.toml
```

After editing, you can simply re-run the installation script to ensure any legacy combined file (if still present) is refreshed, though this is optional now:

```bash
curl -sSL https://raw.githubusercontent.com/AmedeoV/gitleaks-pre-commit-hook/refs/heads/main/gitleaks-local-git-pre-hook.sh | bash
```

You no longer need to manually append anything; the hook reads the custom rules file directly (and defaults). The custom rules file already includes:
- Database connection string detection
- Generic password pattern detection
- API key and token detection

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

#### Configuration Priority

Current resolution order:

1. (Legacy) Repository root `.gitleaks.toml` if present – for backward compatibility.
2. (Legacy) Global `~/.gitleaks.toml` if present – still honored.
3. Active custom rules in `~/.gitleaks-custom-rules.toml` merged with built‑in defaults.
4. Built‑in Gitleaks defaults if no custom file exists.

For new setups you only need `~/.gitleaks-custom-rules.toml`. Add a repo-specific file only if you need an override.

#### File Overview

```
~/.gitleaks-custom-rules.toml    # Your custom rules (edit this as needed)
~/.git-hooks/pre-commit          # Global pre-commit hook invoking gitleaks
```

If a legacy `~/.gitleaks.toml` exists it will be used automatically, but it is optional going forward.

For advanced configuration options (e.g., excluding paths, customizing report formats), see the [Gitleaks documentation](https://github.com/gitleaks/gitleaks#configuration).
