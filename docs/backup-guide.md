# Backup and Restore Guidance

## Database backup
- `docker compose -f deploy/docker-compose.prod.yml exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > backup.sql`

## Environment backup
- `cp .env .env.backup.$(date +%F)`

## Volume backup
- `docker run --rm -v nextgn_data:/from -v "$PWD":/to alpine sh -c 'cd /from && tar -czf /to/volume-backup.tgz .'`

## Restore flow
1. Stop services: `docker compose -f deploy/docker-compose.prod.yml down`.
2. Restore `.env` and volumes/database artifacts.
3. Start services and run verification.
4. Confirm app health (`scripts/support-bundle.sh` for diagnostics).
