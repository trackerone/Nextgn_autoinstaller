# Server Requirements

## Supported OS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## Minimum Hardware
- 2 vCPU
- 2 GB RAM
- 10 GB free disk (more recommended for logs/backups)

## Required Software
- Docker Engine + Docker Compose plugin (`docker compose`) in preinstalled mode, or
- Installer Docker provisioning enabled with `--install-docker` / `NEXTGN_INSTALL_DOCKER=true` (Ubuntu 22.04/24.04 only).
- Git
- Open ports: 80, 443

## DNS
- An A/AAAA record must point the domain to the target host before SSL/proxy setup.

## Admin Bootstrap Inputs
If enabling first-admin bootstrap, provide:
- `NEXTGN_CREATE_ADMIN=true`
- `NEXTGN_ADMIN_NAME`
- `NEXTGN_ADMIN_EMAIL`
- `NEXTGN_ADMIN_PASSWORD_FILE` (recommended) or `NEXTGN_ADMIN_PASSWORD`
