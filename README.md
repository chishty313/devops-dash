# QSL DevOps Engineer Practical Task

**How to evaluate in 3 clicks:** open `https://qtec.chishty.me/` -> open `https://qtec-k8.chishty.me/` -> open `https://qtec.chishty.me/grafana/` (login: `admin` / `Qtec@2026`).

Production-grade DevOps implementation of a MERN API+UI platform with:

- automated CI/CD to a live Azure VM
- zero-downtime blue/green deployments
- traffic shaping and reverse proxy hardening
- observability with Prometheus + Grafana
- optional Kubernetes lane on the same server
- optional Terraform IaC for reproducible infrastructure

## 60-Second Submission Checklist

- **Live app (required lane):** open `https://qtec.chishty.me/`
- **API health (required lane):** open `https://qtec.chishty.me/api/status`
- **Live app (optional k8 lane):** open `https://qtec-k8.chishty.me/`
- **API health (optional k8 lane):** open `https://qtec-k8.chishty.me/api/status`
- **Grafana access:** open `https://qtec.chishty.me/grafana/` (or `https://qtec-k8.chishty.me/grafana/`)
- **Grafana credentials:** `admin` / `Qtec@2026`
- **CI/CD evidence:** GitHub Actions workflows `CI-CD` and `K8s-Deploy`
- **Zero-downtime evidence:** `scripts/deploy.sh` (blue/green cutover with health gating)
- **Kubernetes evidence:** manifests in `k8s/` with Deployment, HPA, PDB, Ingress
- **IaC evidence:** Terraform definitions in `terraform/`

---

## Live Demo (Reviewer Quick Access)

### Core Required Solution (Docker Lane)

- Application: `https://qtec.chishty.me/`
- API Health: `https://qtec.chishty.me/api/status`
- Grafana: `https://qtec.chishty.me/grafana/`

### Optional Solution (Kubernetes Lane)

- Application: `https://qtec-k8.chishty.me/`
- API Health: `https://qtec-k8.chishty.me/api/status`
- Grafana via K8 hostname: `https://qtec-k8.chishty.me/grafana/`
  - This proxies to the same Grafana service used by Docker lane.
  - Depending on `GF_SERVER_ROOT_URL`, Grafana may redirect to `qtec.chishty.me`.

### Grafana Credentials

- Username: `admin`
- Password: `Qtec@2026`

---

## Why This Submission Stands Out

- Built and operated on a real cloud VM with live DNS, TLS, and automated deployments.
- Demonstrates both practical production delivery (Docker) and orchestration readiness (Kubernetes).
- Shows deployment reliability patterns expected from a DevOps Engineer:
  - blue/green release switching
  - health-gated cutover
  - rollback-safe flow
  - CI/CD traceability by commit SHA
- Includes observability and operational runbooks, not only code.

---

## Task Requirement Mapping (`DevOps Engineer Practical Task - QSL.md`)

### Core (Required)

- [x] One GET endpoint + one POST endpoint
- [x] Production-ready Dockerfiles + env configuration
- [x] Nginx reverse proxy + load balancing
- [x] CI/CD pipeline (test → build → push → deploy)
- [x] Zero-downtime deployment implementation and explanation
- [x] Monitoring + logs
- [x] Cloud deployment on Azure VM

### Bonus (Optional)

- [x] Kubernetes manifests with rolling updates and HPA
- [x] Infrastructure as Code (Terraform)
- [x] Secure secret handling + non-root runtime practices

---

## Architecture

```mermaid
flowchart TD
    Internet[Internet] -->|HTTPS :443| EdgeNginx[Docker Nginx Reverse Proxy]

    EdgeNginx -->|qtec.chishty.me| DockerLane[Core Docker Lane]
    EdgeNginx -->|qtec-k8.chishty.me| K8Lane[Optional K8 Lane]

    DockerLane --> FrontendDocker[frontend container]
    DockerLane --> BackendBlue[backend_blue :3000]
    DockerLane --> BackendGreen[backend_green :3000]
    DockerLane --> Prometheus[Prometheus]
    DockerLane --> Grafana[Grafana]

    K8Lane --> NodePort[host.docker.internal:30080]
    NodePort --> Ingress[k3s ingress-nginx]
    Ingress --> K8Frontend[frontend deployment]
    Ingress --> K8Backend[backend deployment]

    BackendBlue --> Atlas[(MongoDB Atlas)]
    BackendGreen --> Atlas
    K8Backend --> Atlas

    GitHub[GitHub Actions] -->|Build+Push| GHCR[ghcr.io]
    GitHub -->|SSH Deploy| AzureVM[Azure Ubuntu VM]
    AzureVM --> EdgeNginx
```

---

## API Endpoints

- `GET /api/status`
  - Returns status, version, uptime, timestamp, environment, and deployment color.
- `POST /api/data`
  - Accepts JSON payload:
    ```json
    { "key": "environment", "value": "production" }
    ```
  - Persists data to MongoDB Atlas.
- `GET /api/metrics`
  - Prometheus-compatible metrics endpoint.

---

## Core Lane (Docker) — Professional Summary

### Runtime Components

- `backend_blue`, `backend_green` (Express API)
- `frontend` (Vite static app served by Nginx)
- `nginx` (edge reverse proxy + TLS)
- `prometheus`, `grafana` (monitoring stack)

### Reverse Proxy and Traffic Management

Defined in `nginx/conf.d/default.conf`:

- HTTP → HTTPS redirect
- `/` → frontend
- `/api/` → backend upstream with `least_conn`
- `/grafana/` → Grafana
- ~100 req/s edge rate limiting + burst
- hardened response headers + TLS termination

### Zero-Downtime Delivery (Blue/Green)

Implemented by `scripts/deploy.sh`:

1. reads active color from `.active_color`
2. starts inactive backend
3. waits for health probe success
4. atomically switches upstream to new color
5. gracefully reloads nginx
6. stops old backend

This prevents user-impacting downtime during deployments.

---

## Optional Lane (Kubernetes on Same VM)

### Design Goal

Add Kubernetes orchestration **without risking the stable core lane**.

- separate domain (`qtec-k8.chishty.me`)
- separate runtime path (k3s + ingress)
- same image supply chain (GHCR)
- same server footprint

### Key Implementation

- k3s installed with Traefik disabled (avoids edge port conflict)
- ingress-nginx exposed via NodePort `30080`
- edge nginx proxies K8 domain traffic to NodePort
- K8 manifests include:
  - Deployments
  - Services
  - Ingress
  - HPA
  - PDB
  - Namespace

### Important Operational Note

`nginx/conf.d/k8s.conf` is intentionally **not committed**.

- template is tracked as `nginx/conf.d/k8s.conf.example`
- active `k8s.conf` is created on VM after certificate issuance
- this avoids failed nginx reloads when cert files are missing on fresh clones

---

## CI/CD Pipelines

### `CI-CD` (`.github/workflows/ci-cd.yml`)

- PR to `main`: run tests only
- Push to `main`:
  1. test backend
  2. build + push backend and frontend images to GHCR
  3. SSH to VM
  4. update `.env` image tag and owner
  5. run Docker blue/green deploy

### `K8s-Deploy` (`.github/workflows/k8s-deploy.yml`)

- triggered after successful `CI-CD` on `main`
- can be executed manually using `workflow_dispatch`
- deploys K8 manifests using commit SHA image tags
- performs rollout waits with diagnostics on failure

### GitHub Secrets Required

- `SSH_PRIVATE_KEY`
- `SERVER_IP`
- `SERVER_USER`
- `DEPLOY_PATH` (optional; defaults to `/opt/qtec`)

---

## Monitoring and Logs

### Monitoring

- Prometheus scrapes backend metrics
- Grafana dashboard includes API RPS, latency, and error visibility

### Logging

- app logs via Winston
- request logs via Morgan
- reverse proxy logs via nginx
- container logs:
  - `docker compose logs`
  - `kubectl logs` (K8 lane)

---

## How the Platform Handles ~100 req/s

- edge rate limiting at nginx (`100r/s` + burst controls)
- tuned keepalive and worker settings
- blue/green service capacity in Docker lane
- HPA-enabled horizontal scaling in Kubernetes lane
- asynchronous Node.js processing and MongoDB pooling

Load-test targets:

- `https://qtec.chishty.me/api/status`
- `https://qtec-k8.chishty.me/api/status`

---

## Engineer Runbook (Detailed Operations)

### A) Core Docker Lane (Required)

#### One-time setup on VM

1. clone repo to `/opt/qtec` (or configure `DEPLOY_PATH`)
2. create root `.env` from `.env.example`
3. set `MONGODB_URI` and runtime vars
4. issue TLS cert for `qtec.chishty.me`
5. deploy:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

#### Ongoing release flow

- push to `main`
- `CI-CD` deploys automatically

#### Verification

```bash
curl -sS https://qtec.chishty.me/api/status
curl -sS -X POST https://qtec.chishty.me/api/data \
  -H "Content-Type: application/json" \
  -d '{"key":"demo","value":"ok"}'
```

### B) Optional Kubernetes Lane (Isolated Same-Server)

#### One-time setup

1. bootstrap k3s + ingress:

```bash
chmod +x scripts/k8s-setup.sh
./scripts/k8s-setup.sh
```

2. add DNS A record:
   - host: `qtec-k8`
   - value: VM public IP

3. issue TLS cert:

```bash
sudo certbot certonly --standalone -d qtec-k8.chishty.me
```

4. enable K8 vhost and reload nginx:

```bash
cp nginx/conf.d/k8s.conf.example nginx/conf.d/k8s.conf
docker compose up -d
docker compose exec nginx nginx -t && docker compose exec nginx nginx -s reload
```

5. create Kubernetes secret:

```bash
kubectl create secret generic qtec-secrets \
  --namespace=qtec \
  --from-literal=mongodb_uri='mongodb+srv://USER:PASS@CLUSTER.mongodb.net/qtec?retryWrites=true&w=majority'
```

#### Ongoing release flow

- push to `main`
- `CI-CD` publishes images
- `K8s-Deploy` applies manifests and rolls pods

#### Verification

```bash
curl -sS https://qtec-k8.chishty.me/api/status
kubectl get pods,svc,ingress,hpa,pdb -n qtec
```

---

## Terraform (Optional IaC)

`terraform/` provisions:

- resource group
- vnet + subnet
- nsg
- static public ip
- ubuntu vm
- cloud-init bootstrap for docker + repo setup

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

---

## Security Practices

- no secrets committed in git
- env files are gitignored
- GitHub Actions uses encrypted secrets for server access
- backend image runs as non-root
- kubernetes database URI injected through secret (`qtec-secrets`)

---

## Troubleshooting (Most Common)

- `nginx: host not found in upstream backend_blue:3000`
  - Start compose services first: `docker compose up -d`
- ingress rejected with `configuration-snippet ... cannot be used`
  - snippet annotations are disabled by ingress admin; manifest already aligned.
- `qtec-k8` marked insecure
  - confirm TLS cert exists for `qtec-k8.chishty.me`, then enable `k8s.conf` and reload nginx.
- `K8s-Deploy` rollout timeout
  - inspect `kubectl describe pod -n qtec -l app=frontend` and `kubectl logs -n qtec -l app=frontend`.

---

## VM Delivery Effort (Operational Scope Highlight)

This project was not only built; it was operated end-to-end on a real VM environment:

- DNS mapping and TLS certificates for two live hostnames
- secure SSH-based deployment automation from GitHub Actions
- production-safe blue/green releases on every main-branch push
- isolated Kubernetes orchestration lane on the same server
- live monitoring stack and on-host troubleshooting workflows

This demonstrates practical DevOps ownership from code to production runtime.
