# Security Policy

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report privately through GitHub: go to the repository's **Security** tab and choose **Report a vulnerability**. Include:

- what the issue is and its impact
- steps to reproduce, or a proof of concept
- the TokenBar and macOS versions you tested

If you can't use GitHub's private reporting, email [meet30997@gmail.com](mailto:meet30997@gmail.com) instead.

You should get an acknowledgement within 7 days. Once a fix is ready, it will ship in a new release and the advisory will be published with credit to you, unless you prefer to stay anonymous.

## Scope

TokenBar runs locally and touches sensitive material, so these areas are especially relevant:

- running the `claude`, `codex`, and `agy` CLIs as subprocesses
- reading `~/.claude`, `~/.codex/auth.json`, and `~/.gemini` data
- connecting to the local Antigravity app service on localhost
- anything that could cause data or credentials to leave the machine
