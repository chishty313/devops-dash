# Knowledge Base - QTEC DevOps Task

This document records what was implemented and how to operate/troubleshoot it.

## Implemented Components

## Backend (`backend/`)

- Express API with:
  - `GET /api/status`
  - `POST /api/data`
  - `GET /api/metrics`
- Input validation via `express-validator`
- MongoDB persistence through Mongoose (MongoDB Atlas via `MONGODB_URI`; no MongoDB container in Compose)
- Logging:
  - Winston structured logs
  - Morgan HTTP access logs
- Metrics:
  - `http_requests_total`
  - `http_request_duration_seconds`
  - default Node.js runtime metrics
- Tests:
  - Jest + Supertest in `backend/tests/api.test.js`

## Frontend (`frontend/`)

- React + Vite dashboard:
  - `StatusCard` polls status every 5 seconds
  - `DataForm` submits POST payloads to API
- Tailwind CSS setup (`tailwind.config.js`, `postcss.config.js`)

## Reverse Proxy (`nginx/`)

- HTTPS termination for `qtec.chishty.me`
- HTTP -> HTTPS redirect
- Route split:
  - `/api/` -> backend upstream
  - `/grafana/` -> grafana
  - `/` -> frontend
- Rate limiting configured at 100 RPS + burst
- Security headers enabled

## Deployment (`scripts/deploy.sh`)

Blue-green deployment implementation:

1. Reads active color (`/opt/qtec/.active_color`)
2. Starts inactive backend
3. Health checks inactive backend
4. Rewrites upstream to inactive backend
5. Reloads Nginx gracefully
6. Stops old backend
7. Persists new active color

## CI/CD (`.github/workflows/ci-cd.yml`)

- Trigger: push to `main`
- Stages:
  - test backend
  - build and push backend/frontend images to GHCR
  - SSH deploy on Azure VM

## Monitoring (`monitoring/`)

- Prometheus scrapes both backend containers.
- Grafana auto-provisions:
  - Prometheus datasource
  - API dashboard JSON

## Optional Bonus

- Kubernetes manifests (`k8s/`)
- Terraform Azure VM foundation (`terraform/`)

## Required Runtime Secrets / Variables

Use `.env` based on `.env.example`:

- `DOMAIN`
- `NODE_ENV`
- `APP_VERSION`
- `LOG_LEVEL`
- `MONGODB_URI` (Atlas SRV string with database name in the path)
- `IMAGE_TAG`
- `COMPOSE_PROJECT_NAME`
- `GITHUB_OWNER`

See [docs/ATLAS_PORT80_AND_GITHUB_SECRETS.md](docs/ATLAS_PORT80_AND_GITHUB_SECRETS.md).

## Common Operations

## Bring up services

```bash
docker compose up -d
```

## Check service status

```bash
docker compose ps
curl https://qtec.chishty.me/api/status
```

## Tail logs

```bash
docker compose logs -f nginx backend_blue backend_green
```

## Manual deployment

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## Rollback strategy

If a deploy fails before Nginx switch, active service remains unchanged.
If manual rollback is required after switch:

1. Edit `nginx/conf.d/backend_upstream.conf` to old color.
2. Reload Nginx:
   ```bash
   docker compose exec -T nginx nginx -s reload
   ```
3. Update `/opt/qtec/.active_color` accordingly.

## Troubleshooting

## TLS errors

- Ensure DNS `qtec.chishty.me` points to VM.
- Verify cert files exist under:
  `/etc/letsencrypt/live/qtec.chishty.me/`

## CI deploy failures

- Check GitHub secrets:
  - `SSH_PRIVATE_KEY`
  - `SERVER_IP`
  - `SERVER_USER`
- Image push uses `GITHUB_TOKEN` (no `GHCR_TOKEN` secret required).
- Ensure VM path is `/opt/qtec` and `.env` has **`GITHUB_OWNER` in lowercase** to match GHCR image names.

## Grafana not loading under `/grafana`

- Verify:
  - `GF_SERVER_ROOT_URL=https://qtec.chishty.me/grafana/`
  - `GF_SERVER_SERVE_FROM_SUB_PATH=true`
- Check Nginx `/grafana/` proxy block.
