### OpenBroadcaster (observer) in Docker

This image builds assets and runs the Observer server in a single container. The application is self-contained and ready after a single command.

- Apache + PHP 8.2 runtime with required extensions
- Assets are built during the image build
- Configuration is generated automatically on first start
- Data persists via a single volume path

---

### Build the image
```bash
docker build -t observer:local .
```

---

### Run the container
```bash
# optional: create a local directory for persistence
mkdir -p ~/observer-data

# start the server
docker run --name observer \
  -p 8080:80 \
  -e OB_SITE="http://localhost:8080/" \
  -v ~/observer-data:/var/ob \
  observer:local
```
Then open http://localhost:8080/ in your browser.

---

### Optional environment variables
- **OB_SITE**: public base URL of Observer (include trailing slash)
- **OB_HASH_SALT**: password pepper for hashing. Auto-generated and persisted on first start at `/var/ob/secrets/hash_salt`. You can override by setting this env var, but do not change it after users exist.
- **OB_ENABLE_CRON_MONITOR**: run background cron monitor (0/1, default 1)
- **OB_RUN_UPDATES_ON_STARTUP**: run database updates automatically at boot (0/1, default 1)

You may also override these default data locations under `/var/ob` if needed:
- `OB_MEDIA_BASE` (default `/var/ob/media`)
- `OB_THUMBNAILS` (default `/var/ob/thumbnails`)
- `OB_CACHE` (default `/var/ob/cache`)

---

### Useful container commands
- Validate install:
```bash
docker exec -it observer tools/cli/ob check
```
- Run updates manually:
```bash
docker exec -it observer tools/cli/ob updates run all
```
- Set admin password (interactive):
```bash
docker exec -it observer tools/cli/ob passwd admin
```
- Run cron once:
```bash
docker exec -it observer tools/cli/ob cron run
```

---

### Persistence
Bind-mount a host directory to persist app data across restarts/upgrades:
- `/var/ob` – contains media, thumbnails, cache, and application data

The password hashing pepper is persisted at `/var/ob/secrets/hash_salt`. Keep this file secret and stable. If you are migrating from an older container that used a custom `OB_HASH_SALT`, either set the same value via `-e OB_HASH_SALT=...` on first start or place the value into `/var/ob/secrets/hash_salt` before starting to preserve existing password hashes.

---

### Security hardening (optional)
Add flags as needed:
```bash
--read-only \
--cap-drop=ALL \
--tmpfs /tmp:rw,noexec,nosuid,size=64m \
--user 33:33
```

---

### Stop / Start
```bash
docker stop observer
docker start observer
```

Remove when done:
```bash
docker rm -f observer
```
