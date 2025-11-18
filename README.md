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
echo 'password="fakePassword123"' > fake_secret.txt
git add fake_secret.txt
git commit -m "Add fake secret for testing"
```

Gitleaks should detect the fake secret, and the pre-commit hook will block the commit. You will see an error message similar to:

```
Finding:     password="fakePassword123"
Secret:      password="fakePassword123"
RuleID:      hardcoded-password
Entropy:     3.251629
File:        fake_secret.txt
Line:        1
Commit:      (staged changes)

1 commits scanned.
1 leaks detected.
```

This confirms that the pre-commit hook is working. Remember to remove the fake password/key after testing.

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

A Gitleaks configuration file is placed at `~/.gitleaks.toml`. You can modify it following the [Gitleaks documentation](https://github.com/gitleaks/gitleaks#configuration). This should allow adjusting the sensitivity and configuring other parameters to suit your needs. For instance, you can add patterns to the allowlist for false positives or customize detection rules.

The default configuration includes:
- Detection of hardcoded passwords
- Detection of generic API keys
- Allowlist for common false positives (masked passwords, example/test passwords)

You can extend the configuration with additional rules or modify existing ones based on your security requirements.
