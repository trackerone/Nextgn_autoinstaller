# NextGN Installer

Production-oriented Bash installer for deploying **NextGN Tracker** to a clean Ubuntu 22.04/24.04 VPS or dedicated server.

## Features
- Modular installer architecture under `installer/lib`.
- Preflight checks for OS, privileges, disk, RAM, Docker, Docker Compose, DNS/domain, and open ports.
- Safe logging to `/var/log/nextgn-installer.log`.
- Human-readable terminal output with colorized status markers.
- Dry-run mode (`--dry-run`) for safe planning.
- Non-destructive defaults (no force changes unless explicitly requested).
- Template provisioning for `.env`, `docker-compose.prod.yml`, and `nginx.conf`.
- Placeholder license validation interface for future activation flow.

## Quick Start
```bash
git clone <your-repo-url> nextgn-installer
cd nextgn-installer
chmod +x installer/nextgn-install.sh
sudo ./installer/nextgn-install.sh \
  --domain tracker.example.com \
  --app-dir /opt/nextgn-tracker \
  --repo https://github.com/your-org/nextgn_tracker.git
```

## Dry Run Example
```bash
sudo ./installer/nextgn-install.sh \
  --domain tracker.example.com \
  --app-dir /opt/nextgn-tracker \
  --repo https://github.com/your-org/nextgn_tracker.git \
  --dry-run
```

## Command Options
- `--domain <fqdn>`: Target domain for DNS and nginx template checks.
- `--app-dir <path>`: Install directory for NextGN Tracker clone.
- `--repo <git_url>`: Git repository URL for NextGN Tracker.
- `--branch <name>`: Git branch to clone (default: `main`).
- `--license-key <key>`: Optional license key string.
- `--force`: Allow controlled overwrite actions.
- `--dry-run`: Print operations without changing the system.
- `--help`: Show help output.

## Project Structure
```text
installer/
  nextgn-install.sh
  lib/
    checks.sh
    config.sh
    license.sh
    logging.sh
    output.sh
    runner.sh
    templates.sh
docs/
  install-guide.md
  server-requirements.md
  troubleshooting.md
.github/workflows/
  shellcheck.yml
```

## Security Notes
- No secrets are committed.
- No license keys are hardcoded.
- License validation is a placeholder module with a clean, replaceable interface.
