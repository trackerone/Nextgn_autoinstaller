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


## Founder Pre-Alpha Local Mode

If you are rehearsing on a laptop or LAN server, use `--local` with `localhost`, a `.local`/`.test` host, or a private LAN IP address. Local mode intentionally prints `Local install mode enabled: public DNS validation skipped.` and does not run public DNS validation.

Do not combine `--local` with `--enable-tls`; the installer rejects that combination because TLS belongs to the normal production/VPS domain flow. For production, remove `--local`, use a real FQDN, and make sure DNS points at the VPS before enabling TLS.

```bash
sudo ./installer/nextgn-install.sh --local --domain nextgn.local --repo <repo-url> --dry-run
```

## TLS and certificate issues

Caddy owns ports 80 and 443 and manages certificate issuance and renewal automatically. Before using `--enable-tls`, confirm that the domain's public A/AAAA records resolve to the server and that inbound TCP ports 80 and 443 are open.

Check certificate and ACME activity with:

```bash
docker compose --env-file .env -f deploy/docker-compose.prod.yml logs caddy
```

Certificate state is stored in the `caddy-data` named volume. Do not delete that volume during ordinary updates or troubleshooting.

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

## Admin Bootstrap Issues
- `Invalid admin email format`: set a valid `--admin-email` / `NEXTGN_ADMIN_EMAIL`.
- `Admin password must be at least 12 characters`: use a stronger password.
- `provide --admin-password-file or --admin-password`: supply credentials when `--create-admin` is enabled.
- Prefer `--admin-password-file` in production; inline password is for CI/unattended automation only.


## Validation failures on real VPS

Run:

```bash
sudo ./scripts/validate-vps-install.sh --domain <fqdn> --install-dir /opt/nextgn-tracker --tls
```

- Review `validation-report.txt` for recommended next action.
- Inspect `validation-report.json` for automation/structured triage.
- If final status is `FAIL`, run `scripts/support-bundle.sh <output-dir>` (or pass `--support-bundle`).
