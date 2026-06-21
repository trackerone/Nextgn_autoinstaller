# NextGN Installer

Production-oriented Bash installer for deploying **NextGN Tracker** to a clean Ubuntu 22.04/24.04 VPS or dedicated server.

## Features
- Modular installer architecture under `installer/lib`.
- Preflight checks for OS, privileges, disk, RAM, Docker, Docker Compose, DNS/domain, and open ports.
- Optional zero-to-production Docker provisioning via `--install-docker` or `NEXTGN_INSTALL_DOCKER=true`.
- Safe logging to `/var/log/nextgn-installer.log`.
- Human-readable terminal output with colorized status markers.
- Dry-run mode (`--dry-run`) for safe planning.
- Founder pre-alpha local install mode (`--local` or `NEXTGN_LOCAL_INSTALL=true`) for laptop/LAN rehearsal without public DNS or TLS.
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


## Founder Pre-Alpha Local Install

Use founder pre-alpha local install mode when you want to rehearse NextGN on a local Ubuntu Server laptop or LAN box before provisioning a real VPS. This mode is explicitly for founder-only local/LAN validation, not production hosting.

Local mode accepts practical local targets such as `nextgn.local`, `nextgn.test`, `localhost`, or private LAN IP addresses like `192.168.1.50` and `10.0.0.25`. Public DNS validation is skipped in this mode, and TLS is not enabled; production/VPS installs should use a real FQDN and must not pass `--local`.

Example dry run:

```bash
sudo ./installer/nextgn-install.sh \
  --local \
  --domain nextgn.local \
  --app-dir /opt/nextgn-tracker \
  --repo https://github.com/your-org/nextgn_tracker.git \
  --dry-run
```

Example local rehearsal install:

```bash
sudo ./installer/nextgn-install.sh \
  --local \
  --domain 192.168.1.50 \
  --app-dir /opt/nextgn-tracker \
  --repo https://github.com/your-org/nextgn_tracker.git \
  --install-docker
```

Environment equivalent:

```bash
NEXTGN_LOCAL_INSTALL=true sudo -E ./installer/nextgn-install.sh \
  --domain nextgn.test \
  --repo https://github.com/your-org/nextgn_tracker.git \
  --dry-run
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
- `--domain <fqdn>`: Target domain for DNS and nginx template checks. In `--local` mode this may be `localhost`, a `.local`/`.test` host, or a private LAN IP address.
- `--install-dir <path>`: Install directory for NextGN Tracker clone.
- `--repo <git_url>`: Git repository URL for NextGN Tracker.
- `--branch <name>`: Git branch to clone (default: `main`).
- `--license-key <key>`: Optional license key string.
- `--local`: Enable founder pre-alpha laptop/LAN rehearsal mode. Public DNS validation and TLS are skipped; do not use for production/VPS installs.
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
  ci.yml
```

## Security Notes
- No secrets are committed.
- No license keys are hardcoded.
- License validation is a placeholder module with a clean, replaceable interface.


## Install Modes

A) Preinstalled Docker mode:
```bash
./installer/nextgn-install.sh --domain example.com --repo <repo-url>
```

B) Zero-to-production mode:
```bash
./installer/nextgn-install.sh --domain example.com --repo <repo-url> --install-docker
```

Environment toggle:
```bash
NEXTGN_INSTALL_DOCKER=true ./installer/nextgn-install.sh --domain example.com --repo <repo-url>
```

## First Admin Bootstrap

By default, installer does **not** create an admin automatically.

Enable unattended first-sysop bootstrap:
```bash
NEXTGN_CREATE_ADMIN=true \
NEXTGN_ADMIN_NAME="Site Owner" \
NEXTGN_ADMIN_EMAIL="admin@example.com" \
NEXTGN_ADMIN_PASSWORD_FILE="/root/nextgn-admin-password" \
./installer/nextgn-install.sh --domain example.com --repo <repo> --install-docker
```

Security:
- Prefer password file over inline password.
- Avoid putting production passwords in shell history.
- Set strict permissions: `chmod 600 /root/nextgn-admin-password`.



## Release Readiness (Slice 10)

Run the release readiness workflow before cutting `v0.1.0-beta` artifacts:

```bash
./scripts/release-readiness.sh
```

This runs:
- repository self-test
- shell test suite in `tests/*.sh`
- deterministic release packaging (`scripts/release.sh`)
- artifact integrity verification (`scripts/verify-release.sh`)

## Real VPS validation (Ubuntu 22.04/24.04)

After running the installer on a real VPS, run:

```bash
sudo ./scripts/validate-vps-install.sh   --domain tracker.example.com   --install-dir /opt/nextgn-tracker   --tls   --support-bundle
```

Outputs:
- `validation-report.json` (machine-readable)
- `validation-report.txt` (human-readable)

Exit code is `0` for pass/warn and `1` if any check fails.
