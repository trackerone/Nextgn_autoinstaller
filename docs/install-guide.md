# Install Guide

1. Provision a clean Ubuntu 22.04/24.04 server.
2. Install Docker + Docker Compose plugin.
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
