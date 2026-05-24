# Troubleshooting

## Unsupported OS
If installer exits with unsupported OS, verify `/etc/os-release` reports Ubuntu 22.04 or 24.04.

## Missing Docker
If Docker is missing or unhealthy, rerun with:

```bash
./installer/nextgn-install.sh --domain example.com --repo <repo-url> --install-docker
```

Or set:

```bash
NEXTGN_INSTALL_DOCKER=true
```

Installer does not install Docker unless explicitly requested.

## Port Conflicts
If ports 80/443 are busy, stop conflicting services or adjust reverse proxy architecture before deployment.

## Permission Errors
Run installer as root or with passwordless sudo.

## Existing Files
Installer is non-destructive by default. Use `--force` only when you explicitly want to overwrite templates.

## Rollback / Uninstall (Documentation-Only)

Destructive uninstall is intentionally not implemented yet.

For rollback planning:
1. Stop application containers (`docker compose down`) from your app directory.
2. Restore previous app revision with git and recreate containers.
3. Restore previous `.env` and reverse proxy config from backups.
4. Review `/var/lib/nextgn-installer/state` to understand completed installer steps.
5. Remove installer-managed artifacts manually only after backup verification.

> TODO: Add a guided rollback command once safety checks and backup validation are finalized.
