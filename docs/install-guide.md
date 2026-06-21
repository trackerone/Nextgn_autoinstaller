# Install Guide

1. Provision a clean Ubuntu 22.04/24.04 server.
2. Choose one mode:
   - Preinstalled Docker mode: install Docker + Docker Compose plugin before running installer.
   - Zero-to-production mode: pass `--install-docker` (or `NEXTGN_INSTALL_DOCKER=true`) to let installer provision Docker explicitly.
3. Clone this installer repository.
4. Run:
   ```bash
   sudo ./installer/nextgn-install.sh \
     --domain tracker.example.com \
     --app-dir /opt/nextgn-tracker \
     --repo https://github.com/your-org/nextgn_tracker.git
   ```
5. Review generated templates in target app directory.
6. Execute app bootstrap lifecycle inside cloned NextGN Tracker repo:
   - environment setup
   - migrations
   - cache warmup
   - permissions


## Founder Pre-Alpha Local/LAN Rehearsal

For founder-only pre-alpha rehearsal on a local Ubuntu Server laptop or LAN server, pass `--local` or set `NEXTGN_LOCAL_INSTALL=true`. This mode is not production mode: it permits local hosts such as `nextgn.local`, `nextgn.test`, `localhost`, and private LAN IP addresses, skips public DNS validation, and rejects TLS because local rehearsal does not use the public certificate flow.

Dry-run example:

```bash
sudo ./installer/nextgn-install.sh --local --domain nextgn.local --repo https://github.com/your-org/nextgn_tracker.git --dry-run
```

Real local rehearsal example:

```bash
sudo ./installer/nextgn-install.sh --local --domain 192.168.1.50 --repo https://github.com/your-org/nextgn_tracker.git --install-docker
```

Do not use `--local` for production VPS installs. Production installs should keep the normal real-domain DNS flow and use `--enable-tls` only with a public FQDN that resolves correctly.

## Dry Run
```bash
sudo ./installer/nextgn-install.sh --domain tracker.example.com --repo https://github.com/your-org/nextgn_tracker.git --dry-run
```


## Mode Examples

```bash
./installer/nextgn-install.sh --domain example.com --repo <repo-url>
./installer/nextgn-install.sh --domain example.com --repo <repo-url> --install-docker
NEXTGN_INSTALL_DOCKER=true ./installer/nextgn-install.sh --domain example.com --repo <repo-url>
```

## Admin Bootstrap

Interactive/manual mode:
```bash
./installer/nextgn-install.sh --domain example.com --repo <repo>
```

Unattended admin bootstrap:
```bash
NEXTGN_CREATE_ADMIN=true \
NEXTGN_ADMIN_NAME="Site Owner" \
NEXTGN_ADMIN_EMAIL="admin@example.com" \
NEXTGN_ADMIN_PASSWORD_FILE="/root/nextgn-admin-password" \
./installer/nextgn-install.sh --domain example.com --repo <repo> --install-docker
```

Use `chmod 600 /root/nextgn-admin-password` and avoid inline production passwords.


## Real VPS validation flow

Example production-like install:

```bash
sudo ./installer/nextgn-install.sh   --domain tracker.example.com   --repo https://github.com/trackerone/nextgn_tracker.git   --install-docker   --enable-tls   --create-admin   --admin-name "Site Owner"   --admin-email admin@example.com   --admin-password-file /root/nextgn-admin-password
```

Then validate on the same VPS:

```bash
sudo ./scripts/validate-vps-install.sh   --domain tracker.example.com   --install-dir /opt/nextgn-tracker   --tls   --support-bundle
```
