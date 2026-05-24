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
