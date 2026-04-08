# QSL DevOps Engineer Practical Task

Production-style MERN stack deployment for `qtec.chishty.me` with containerization, reverse proxy, CI/CD, zero-downtime deployment, and observability.

## 1) System Architecture

```mermaid
flowchart TD
    Internet["Internet"] -->|HTTPS :443| Nginx["Nginx Reverse Proxy\nTLS Termination"]
    Nginx -->|"/"| Frontend["React Frontend\nVite build on nginx:alpine"]
    Nginx -->|"/api/*"| BackendBlue["Express API\nbackend_blue :3000"]
    Nginx -->|"/api/*"| BackendGreen["Express API\nbackend_green :3000"]
    BackendBlue --> MongoDB["MongoDB Atlas\n(mongodb+srv)"]
    BackendGreen --> MongoDB
    BackendBlue -->|"/api/metrics"| Prometheus["Prometheus"]
    BackendGreen -->|"/api/metrics"| Prometheus
    Prometheus --> Grafana["Grafana (/grafana)"]
    GitHub["GitHub Actions"] -->|Build + Push| GHCR["ghcr.io"]
    GitHub -->|SSH Deploy| AzureVM["Azure Ubuntu VM"]
    AzureVM --> Nginx
```

## 2) Application Endpoints

- `GET /api/status`  
  Returns service health and metadata:
  - `status`
  - `version`
  - `uptime`
  - `timestamp`
  - `environment`
  - `color` (blue/green deployment slot)

- `POST /api/data`  
  Accepts JSON:

  ```json
  {
    "key": "environment",
    "value": "production"
  }
  ```

  Persists to MongoDB and returns created object.

- `GET /api/metrics`  
  Prometheus-compatible metrics endpoint.

## 3) Containerization Approach

- Multi-stage backend image in `backend/Dockerfile`
  - Runtime image uses non-root `node` user.
  - Health check probes `/api/status`.
- Multi-stage frontend image in `frontend/Dockerfile`
  - Vite builds static assets.
  - Nginx serves static files.
- `docker-compose.yml` defines:
  - `backend_blue`
  - `backend_green`
  - `frontend`
  - `nginx`
  - `prometheus`
  - `grafana`
- **MongoDB** is **MongoDB Atlas only** (`MONGODB_URI` in `.env`). No MongoDB container is included.

See [docs/ATLAS_PORT80_AND_GITHUB_SECRETS.md](docs/ATLAS_PORT80_AND_GITHUB_SECRETS.md) for Atlas IP allowlist, freeing port 80, and GitHub secrets.

## 4) Reverse Proxy and Traffic Management

Nginx configuration:

- Domain: `qtec.chishty.me`
- HTTP to HTTPS redirect
- TLS cert path: `/etc/letsencrypt/live/qtec.chishty.me/`
- Routing:
  - `/` -> frontend container
  - `/api/` -> backend upstream
  - `/grafana/` -> grafana container
- Load balancing:
  - `least_conn` upstream strategy
- Traffic controls:
  - `limit_req_zone` at `100r/s` with burst `200`
- Security headers:
  - `X-Frame-Options`
  - `X-Content-Type-Options`
  - `HSTS`

## 5) CI/CD Pipeline

Pipeline file: `.github/workflows/ci-cd.yml`

- **Pull requests** to `main`: runs **tests only** (no image push, no deploy).
- **Push** to `main`: tests → build/push images → deploy.

### Stages

1. **Test**
   - `npm ci` + Jest + Supertest (uses `backend/package-lock.json`).

2. **Build & Push**
   - Logs in to GHCR with the workflow **`GITHUB_TOKEN`** (no personal PAT required).
   - Image names use your GitHub owner in **lowercase** (required by GHCR).
   - Push both images to `ghcr.io/<owner>/qtec-backend` and `qtec-frontend` tagged with:
     - commit SHA
     - `latest`

3. **Deploy**
   - SSH to Azure VM.
   - Runs `git fetch` + `git reset --hard origin/main` so the VM matches the repo (local edits to tracked files on the server are discarded).
   - Updates `.env` with `IMAGE_TAG` (SHA) and **lowercase** `GITHUB_OWNER`.
   - Runs `scripts/deploy.sh`.

### GitHub repository secrets (deploy only)

Configure under **Settings → Secrets and variables → Actions**:

| Secret | Required |
|--------|----------|
| `SSH_PRIVATE_KEY` | Yes (full private key for VM SSH) |
| `SERVER_IP` | Yes |
| `SERVER_USER` | Yes |
| `DEPLOY_PATH` | No — absolute path on the VM where the repo is cloned. Defaults to `/opt/qtec` if unset. Example: `/home/azureuser/project/devops-dashboard/devops-dash` |

You do **not** need `GHCR_TOKEN`; the workflow uses built-in `permissions: packages: write`.

### First-time GitHub push

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

Ensure **Settings → Actions → General** allows workflows, and for private repos that **Actions** can read the repo.

## 6) Zero-Downtime Deployment

`scripts/deploy.sh` uses blue-green rollout:

1. Detect current active color from `.active_color` in the project root (same directory as `docker-compose.yml`).
2. Select inactive color for new release.
3. Pull and start inactive backend container.
4. Wait until health check passes on `/api/status`.
5. Rewrite Nginx upstream to point to new color only.
6. Gracefully reload Nginx.
7. Stop old backend container.
8. Persist new active color.

This prevents interruption during deployment because traffic switches only after health success.

## 7) Logging and Monitoring Setup

### Logs

- Application logs: Winston JSON logs from backend.
- Request logs: Morgan access logs routed through Winston.
- Proxy logs: Nginx access/error logs.
- Container logs: via `docker compose logs`.

### Monitoring

- Prometheus scrape targets:
  - `backend_blue:3000/api/metrics`
  - `backend_green:3000/api/metrics`
- Grafana pre-provisioned with:
  - datasource: Prometheus
  - dashboard: API RPS, p95 latency, error ratio, heap usage

## 8) How the System Handles ~100 Requests/sec

The stack supports ~100 RPS through layered controls:

- Nginx reverse proxy optimized with:
  - `worker_processes auto`
  - `worker_connections 2048`
  - keepalive upstream connections
- Two backend slots (blue/green); both can run and serve traffic.
- Node.js async request handling and pooled MongoDB connections.
- API rate limiting at edge (`100r/s`, burst `200`) prevents abuse spikes.
- Lightweight endpoint logic and JSON payload handling.

For formal evidence, run load tests (e.g. k6/hey/wrk) against:

`https://qtec.chishty.me/api/status`

## 9) Local Development

```bash
cp .env.example .env
docker compose up -d --build
```

Test API:

```bash
curl http://localhost/api/status
curl -X POST http://localhost/api/data -H "Content-Type: application/json" -d '{"key":"sample","value":"123"}'
```

## 10) Cloud Deployment on Azure VM

1. Add DNS A record:
   - host: `qtec`
   - value: `<Azure VM Public IP>`
2. Install cert:

```bash
sudo certbot certonly --standalone -d qtec.chishty.me
```

3. Clone the repo to a fixed path on the VM (e.g. `/opt/qtec` or `~/project/.../devops-dash`). If you do not use `/opt/qtec`, set GitHub secret **`DEPLOY_PATH`** to that absolute path.
4. Configure `.env`.
5. Run:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## 11) Optional Bonus — Container Orchestration (Kubernetes)

### Architecture

```
Ingress (nginx-ingress + cert-manager)
  ├── /api  → backend Service → 2–10 backend Pods (HPA)
  └── /     → frontend Service → 1 frontend Pod
                                     ↓
                              mongodb StatefulSet (10 Gi PVC)
```

### Prerequisites

| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes CLI |
| A Kubernetes cluster | AKS / GKE / EKS / local (kind / minikube) |
| [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) | Ingress controller |
| [cert-manager](https://cert-manager.io/) | Automatic TLS from Let's Encrypt |

### Manifest files

| File | What it creates |
|------|----------------|
| `k8s/namespace.yml` | `qtec` namespace |
| `k8s/secrets.example.yml` | Secret template (fill before applying) |
| `k8s/backend-deployment.yml` | 2-replica backend, resource limits, non-root, rolling update |
| `k8s/frontend-deployment.yml` | 1-replica frontend, rolling update |
| `k8s/mongodb-statefulset.yml` | Single MongoDB pod with 10 Gi PVC |
| `k8s/services.yml` | ClusterIP services for backend, frontend, mongodb |
| `k8s/ingress.yml` | TLS ingress with rate-limit and security headers |
| `k8s/hpa.yml` | Horizontal Pod Autoscaler (2–10 pods, CPU 70 % / mem 80 %) |
| `k8s/pdb.yml` | PodDisruptionBudget (minAvailable: 1 — zero-downtime node drains) |

### Deploy steps

```bash
# 1. Create namespace
kubectl apply -f k8s/namespace.yml

# 2. Create secret (never commit real values — use the example as a template)
kubectl create secret generic qtec-secrets \
  --namespace qtec \
  --from-literal=mongodb_uri="mongodb+srv://USER:PASS@cluster.mongodb.net/qtec?retryWrites=true&w=majority" \
  --from-literal=mongo_root_user="admin" \
  --from-literal=mongo_root_password="changeme"

# 3. Apply all remaining manifests
kubectl apply -f k8s/mongodb-statefulset.yml
kubectl apply -f k8s/services.yml
kubectl apply -f k8s/backend-deployment.yml
kubectl apply -f k8s/frontend-deployment.yml
kubectl apply -f k8s/hpa.yml
kubectl apply -f k8s/pdb.yml
kubectl apply -f k8s/ingress.yml

# 4. Watch rollout
kubectl rollout status deployment/backend -n qtec
kubectl rollout status deployment/frontend -n qtec

# 5. Verify pods
kubectl get pods -n qtec
```

### Update image (rolling update — zero downtime)

```bash
# CI sets this; for manual updates:
kubectl set image deployment/backend backend=ghcr.io/your-org/qtec-backend:<SHA> -n qtec
kubectl rollout status deployment/backend -n qtec
```

`maxUnavailable: 0` + `minAvailable: 1` PDB ensures at least one pod serves traffic throughout the rollout.

### Horizontal scaling

The HPA watches CPU (≥ 70 %) and memory (≥ 80 %) and scales from 2 → 10 replicas automatically. Test with:

```bash
# Install k6: https://k6.io/docs/getting-started/installation/
k6 run --vus 50 --duration 60s - <<'EOF'
import http from 'k6/http';
export default () => { http.get('https://qtec.chishty.me/api/status'); }
EOF

kubectl get hpa backend-hpa -n qtec --watch
```

---

## 12) Optional Bonus — Infrastructure as Code (Terraform)

Terraform provisions the Azure VM (Ubuntu 22.04) and all supporting networking from scratch, including a **cloud-init** bootstrap that installs Docker and clones the repo automatically.

### Resources provisioned

| Resource | Description |
|---------|-------------|
| `azurerm_resource_group` | Logical container for all resources |
| `azurerm_virtual_network` | VNet `10.0.0.0/16` |
| `azurerm_subnet` | Subnet `10.0.1.0/24` |
| `azurerm_network_security_group` | Allows SSH (your IP), HTTP 80, HTTPS 443 |
| `azurerm_public_ip` | Static public IP (Standard SKU) |
| `azurerm_linux_virtual_machine` | Ubuntu 22.04 LTS, Standard_B2s (2 vCPU / 4 GB) |
| `custom_data` (cloud-init) | Installs Docker, git; clones repo to `/opt/qtec` |

### Usage

```bash
cd terraform

# 1. Copy and fill in variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: ssh_public_key, allowed_ssh_cidr, repo_url

# 2. Initialise providers
terraform init

# 3. Preview what will be created
terraform plan

# 4. Provision (takes ~2 minutes)
terraform apply

# 5. Note the outputs
# vm_public_ip  → use for DNS A record and GitHub Secrets SERVER_IP
# ssh_command   → copy-paste to connect
```

### What happens after `terraform apply`

1. Azure creates the VM.
2. **cloud-init** runs on first boot (~90 seconds):
   - Installs Docker Engine + Docker Compose plugin.
   - Clones the repo to `/opt/qtec`.
   - Makes `scripts/deploy.sh` executable.
3. Point `qtec.chishty.me` DNS A record to `vm_public_ip`.
4. SSH in and create `/opt/qtec/.env` (copy `.env.example`, fill in `MONGODB_URI`).
5. Run Certbot for TLS, then `./scripts/deploy.sh`.
6. Set GitHub Secrets; subsequent pushes to `main` deploy automatically.

### Tear down

```bash
terraform destroy
```

---

## 13) Optional Bonus — Secrets & Security Management

### Security practices in this repository

| Practice | Where applied |
|---------|--------------|
| **No hardcoded credentials** | All secrets via environment variables / Kubernetes Secrets |
| **Non-root container** | `backend/Dockerfile`: `USER node` (UID 1000) |
| **Read-only root filesystem** | `k8s/backend-deployment.yml`: `readOnlyRootFilesystem: true` |
| **Dropped Linux capabilities** | `k8s/backend-deployment.yml`: `capabilities.drop: [ALL]` |
| **GitHub Actions secrets** | `SSH_PRIVATE_KEY`, `SERVER_IP`, `SERVER_USER` — never in code |
| **Kubernetes Secrets** | `qtec-secrets` for `MONGODB_URI`, Mongo credentials |
| **`secretKeyRef`** | All sensitive env vars in K8s read from the Secret object |
| **`.env` gitignored** | `.env` at repo root is in `.gitignore`; only `.env.example` is committed |
| **SSH key auth only** | NSG + Terraform restrict SSH; no password auth on the VM |

### Secret lifecycle

```
Local dev  → backend/.env         (gitignored, never committed)
CI/CD      → GitHub Actions Secrets (encrypted at rest by GitHub)
Production → /opt/qtec/.env        (on the VM only, not in repo)
Kubernetes → kubectl create secret  (stored encrypted in etcd)
```

### Hardening checklist (production)

- [ ] Change Grafana default password (`GF_SECURITY_ADMIN_PASSWORD` in `.env`)
- [ ] Restrict NSG SSH rule to your static IP (`allowed_ssh_cidr` in `terraform.tfvars`)
- [ ] Use MongoDB Atlas network access list (allowlist only the VM's public IP)
- [ ] Rotate `SSH_PRIVATE_KEY` GitHub Secret if the key is ever compromised
- [ ] Enable Azure Defender for Servers on the resource group (optional, incurs cost)
