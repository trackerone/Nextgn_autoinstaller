# Troubleshooting

## Unsupported OS
If installer exits with unsupported OS, verify `/etc/os-release` reports Ubuntu 22.04 or 24.04.

## Missing Docker
Install Docker Engine and Docker Compose plugin, then re-run installer.

## Port Conflicts
If ports 80/443 are busy, stop conflicting services or adjust reverse proxy architecture before deployment.

## Permission Errors
Run installer as root or with passwordless sudo.

## Existing Files
Installer is non-destructive by default. Use `--force` only when you explicitly want to overwrite templates.
