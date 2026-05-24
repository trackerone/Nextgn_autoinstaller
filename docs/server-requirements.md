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
