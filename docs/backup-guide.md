# Backup and Restore Guidance

Run these commands from the installed NextGN Tracker directory. Store backups outside the application directory and protect them as production secrets.

## MySQL backup

```bash
docker compose --env-file .env -f deploy/docker-compose.prod.yml exec -T database \
  sh -c 'exec mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"' \
  > mysql-backup.sql
```

## Laravel storage backup

The `app-storage` volume contains uploaded torrent files, NFO files, images, logs, and Laravel framework storage shared by the app, queue, and scheduler.

```bash
docker compose --env-file .env -f deploy/docker-compose.prod.yml run --rm --no-deps -T \
  --entrypoint sh app -c 'tar -C /app/storage -czf - .' \
  > app-storage-backup.tgz
```

## Environment backup

Back up both `.env` and `.env.mysql-root` with mode `0600`. They contain the application encryption key and database credentials and must never be committed or included in a public support bundle.

## Restore flow

1. Verify the backup files before stopping services.
2. Run `docker compose --env-file .env -f deploy/docker-compose.prod.yml down`. Do **not** add `--volumes`; that option deletes the named storage and database volumes.
3. Restore `.env` and `.env.mysql-root` with mode `0600`.
4. Restore the MySQL dump into the `database` service.
5. Restore `app-storage-backup.tgz` into `/app/storage` using a one-off `app` container before restarting normal traffic.
6. Start the deployment and run `scripts/validate-vps-install.sh`.

Test the complete restore procedure on a disposable server before relying on it for the controlled alpha.
