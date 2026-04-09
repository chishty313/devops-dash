# K8s Optional Lane — Step-by-Step Guide

This guide gets `qtec-k8.chishty.me` running on the **same server** as your existing
Docker Compose production stack (`qtec.chishty.me`).

**Zero risk to production:** the existing stack is never touched.

---

## How it works (architecture overview)

```
Browser
  │
  ├─ https://qtec.chishty.me ──► nginx (Docker) ──► Docker Compose stack   ← UNTOUCHED
  │
  └─ https://qtec-k8.chishty.me ──► nginx (Docker) ──► port 30080
                                                              │
                                                         k3s (Kubernetes)
                                                              │
                                              ┌───────────────┴──────────────┐
                                         backend pods                   frontend pod
                                         (2 replicas, HPA)
```

- **Same nginx Docker container** handles HTTPS for both domains.
- **k3s** (lightweight Kubernetes) runs on the same VM, listening on NodePort **30080**.
- **No ports 80/443 conflict** — k3s uses internal ports only; Docker nginx is the public entry point.

---

## Part A — One-time server setup (do this first, via SSH)

SSH into your server:

```bash
ssh azureuser@YOUR_VM_IP
cd /opt/qtec      # or your DEPLOY_PATH
```

### Step 1 — Run the k8s setup script

```bash
chmod +x scripts/k8s-setup.sh
./scripts/k8s-setup.sh
```

This script:
- Installs **k3s** (takes ~30 seconds)
- Installs **nginx-ingress-controller** inside k3s
- Pins the ingress to **NodePort 30080**
- Copies the kubeconfig to `~/.kube/config` so you can run `kubectl`

When it finishes, verify k3s is working:

```bash
kubectl get nodes
# Expected output:
# NAME    STATUS   ROLES                  AGE   VERSION
# vm-...  Ready    control-plane,master   1m    v1.xx.x+k3s1

kubectl get pods -n ingress-nginx
# All pods should be Running
```

---

### Step 2 — Add DNS record for the new subdomain

In your DNS provider, add a new **A record**:

| Field | Value |
|-------|-------|
| Host  | `qtec-k8` |
| Type  | A |
| Value | `<YOUR VM PUBLIC IP>` (same IP as the main domain) |

Wait 1–2 minutes, then verify:

```bash
dig +short qtec-k8.chishty.me
# Should print your VM IP
```

---

### Step 3 — Get TLS certificate for the new subdomain

Your existing nginx Docker config expects certs at:

```
/etc/letsencrypt/live/qtec-k8.chishty.me/fullchain.pem
/etc/letsencrypt/live/qtec-k8.chishty.me/privkey.pem
```

**Stop Docker nginx temporarily** (< 10 seconds, prod goes down briefly):

```bash
cd /opt/qtec
docker compose stop nginx
```

**Get the certificate:**

```bash
sudo certbot certonly --standalone -d qtec-k8.chishty.me
```

**Restart nginx:**

```bash
docker compose up -d nginx
```

Verify prod is back:

```bash
curl -sI https://qtec.chishty.me/api/status
# Should return HTTP/2 200
```

---

### Step 4 — Enable the K8s vhost (only after certs exist)

`nginx/conf.d/k8s.conf` is **not** committed: nginx would fail on every deploy if certs were missing. The template is `k8s.conf.example`.

After Step 3 completes (cert files exist under `/etc/letsencrypt/live/qtec-k8.chishty.me/`):

```bash
cd /opt/qtec
cp nginx/conf.d/k8s.conf.example nginx/conf.d/k8s.conf
docker compose exec nginx nginx -t && docker compose exec nginx nginx -s reload
```

Visit `https://qtec-k8.chishty.me/` — a **502** is normal until k8s pods are running.

---

### Step 5 — Create the Kubernetes Secret for MongoDB

This secret stores the MongoDB connection string. It is **never committed to git**.

```bash
kubectl create secret generic qtec-secrets \
  --namespace=qtec \
  --from-literal=mongodb_uri='mongodb+srv://USER:PASS@cluster.mongodb.net/qtec?retryWrites=true&w=majority'
```

Replace `USER`, `PASS`, and the cluster address with your **Atlas** credentials.

**MongoDB Atlas network access:** Add your VM's public IP to Atlas → Network Access → IP Allowlist (the same one you already added for the Docker stack; it should already be there).

Verify the secret was created:

```bash
kubectl get secret qtec-secrets -n qtec
# NAME           TYPE     DATA   AGE
# qtec-secrets   Opaque   1      5s
```

---

### Step 6 — (Only if GHCR packages are private) Create image pull secret

If your GitHub repo's packages are **private**, k3s cannot pull the images without credentials. If your packages are **public**, skip this step.

1. Create a GitHub Personal Access Token (PAT) with `read:packages` scope.
2. Create the pull secret:

```bash
kubectl create secret docker-registry ghcr-pull \
  --namespace=qtec \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_PAT_TOKEN
```

3. Add these two lines under `spec.template.spec` in `k8s/backend-deployment.yml` and `k8s/frontend-deployment.yml`:

```yaml
      imagePullSecrets:
        - name: ghcr-pull
```

Commit and push to main — the workflow will re-apply.

---

## Part B — GitHub Actions (automatic, no manual action needed)

Once Part A is done and you push to `main`, two workflows run:

| Workflow | File | What it does |
|----------|------|-------------|
| **CI-CD** | `.github/workflows/ci-cd.yml` | Tests → builds images → deploys to Docker Compose |
| **K8s-Deploy** | `.github/workflows/k8s-deploy.yml` | Waits for CI-CD to finish → deploys to k3s |

**You do not need to do anything extra.** Just push to `main`.

---

## Part C — Manual first deploy (to test before CI runs)

If you want to test right now without waiting for a push:

```bash
cd /opt/qtec

# Make sure images exist in GHCR (they do if CI-CD ran at least once)
export IMAGE_OWNER=<your-lowercase-github-username>
export IMAGE_TAG=latest

chmod +x scripts/k8s-deploy.sh
./scripts/k8s-deploy.sh
```

---

## Part D — Verify and test everything

Run all these checks from your **laptop** after deployment.

### Check 1 — API status endpoint

```bash
curl -sS https://qtec-k8.chishty.me/api/status | python3 -m json.tool
```

Expected response:

```json
{
  "status": "ok",
  "version": "1.0.0",
  "uptime": 42,
  "timestamp": "2026-04-08T...",
  "environment": "production",
  "color": "blue"
}
```

### Check 2 — POST data endpoint

```bash
curl -sS -X POST https://qtec-k8.chishty.me/api/data \
  -H "Content-Type: application/json" \
  -d '{"key":"k8s-test","value":"hello-from-k8s"}' | python3 -m json.tool
```

Expected: `201` status with an `id` and `createdAt`.

### Check 3 — Frontend loads in browser

Open `https://qtec-k8.chishty.me/` in your browser. The React SPA should load.

### Check 4 — Pods are running (on server)

```bash
kubectl get pods -n qtec
# NAME                        READY   STATUS    RESTARTS   AGE
# backend-xxxxxxxxx-xxxxx     1/1     Running   0          2m
# backend-xxxxxxxxx-yyyyy     1/1     Running   0          2m
# frontend-xxxxxxxxx-xxxxx    1/1     Running   0          2m
```

### Check 5 — HPA is watching

```bash
kubectl get hpa -n qtec
# NAME          REFERENCE             TARGETS          MINPODS   MAXPODS   REPLICAS
# backend-hpa   Deployment/backend    15%/70%, 5%/80%  2         10        2
```

### Check 6 — Rolling update works (zero-downtime)

```bash
# Trigger a rolling update by setting image to "latest"
kubectl set image deployment/backend backend=ghcr.io/<your-username>/qtec-backend:latest -n qtec

# Watch it roll — one old pod stays up until new pod is Ready
kubectl rollout status deployment/backend -n qtec

# Also confirm prod domain still works during the update
curl -sS https://qtec.chishty.me/api/status
```

### Check 7 — PDB is protecting backend

```bash
kubectl get pdb -n qtec
# NAME          MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
# backend-pdb   1               N/A               1                     5m
```

### Check 8 — Ingress is configured

```bash
kubectl get ingress -n qtec
# NAME            CLASS   HOSTS                    ADDRESS     PORTS   AGE
# qtec-ingress    nginx   qtec-k8.chishty.me      10.0.0.1    80      5m
```

### Check 9 — Logs

```bash
# Backend pod logs
kubectl logs -n qtec -l app=backend --tail=30

# Ingress controller logs (see incoming requests)
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=20
```

### Check 10 — Prod is still working

```bash
curl -sS https://qtec.chishty.me/api/status
# Must still return 200 — Docker Compose stack is completely independent
```

---

## Troubleshooting

| Symptom | Where to look | Fix |
|---------|--------------|-----|
| `502 Bad Gateway` on `qtec-k8.chishty.me` | Pods not running yet | `kubectl get pods -n qtec` — wait or check logs |
| `curl: SSL certificate problem` | Cert not issued | Redo Step 3; check `ls /etc/letsencrypt/live/qtec-k8.chishty.me/` |
| `ImagePullBackOff` in pods | GHCR auth needed | Do Step 6 (private packages) |
| `ErrImageNeverPull` | Wrong image tag | Make sure CI ran at least once and `IMAGE_OWNER` is lowercase |
| `Connection refused` on port 30080 | k3s not running | `sudo systemctl status k3s` → `sudo systemctl start k3s` |
| `kubectl: command not found` | KUBECONFIG not set | `export KUBECONFIG=~/.kube/config` or re-run setup script |
| Nginx reload fails | Missing k8s cert | Complete Step 3 first, then reload |
| Prod domain down after cert step | Nginx restart needed | `docker compose up -d nginx` |

---

## Cert renewal (automated)

Certbot installs a cron job/systemd timer for auto-renewal. For the standalone renewal to
work, port 80 must be free. Add a renewal hook to stop/start Docker nginx:

```bash
sudo nano /etc/letsencrypt/renewal-hooks/pre/stop-nginx.sh
```

Content:

```bash
#!/bin/bash
cd /opt/qtec && docker compose stop nginx
```

```bash
sudo nano /etc/letsencrypt/renewal-hooks/post/start-nginx.sh
```

Content:

```bash
#!/bin/bash
cd /opt/qtec && docker compose up -d nginx
```

```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/pre/stop-nginx.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/post/start-nginx.sh
```

Test: `sudo certbot renew --dry-run`
