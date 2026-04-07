# MongoDB Atlas, port 80, and GitHub secrets

## MongoDB Atlas (local + production)

1. **Cluster**: Atlas → Create / use a cluster.
2. **Database user**: Atlas → Database Access → add user with password (save it).
3. **Network Access**: Atlas → Network Access → Add IP Address:
   - **Local dev**: add your current public IP, or `0.0.0.0/0` only for quick tests (not recommended long term).
   - **Azure VM**: add the VM’s **public** IP (or a temporary `0.0.0.0/0` while debugging).
4. **Connection string**: Atlas → Database → Connect → Drivers → copy `mongodb+srv://...`
   - Insert **database name** before `?`, e.g. `...mongodb.net/qtec?retryWrites=true&w=majority`.
5. **Project env**:
   - **Docker (VM)**: set `MONGODB_URI` in `/opt/qtec/.env` (repo root `.env`).
   - **Local `npm run dev`**: set `MONGODB_URI` in `backend/.env` (can be the same URI or a dev database name).

This repo’s `docker-compose.yml` does **not** run a local MongoDB container; backends use `MONGODB_URI` only.

---

## Free port 80 (and 443) for Certbot or Nginx

If **Caddy** (or anything else) is bound to `80`/`443`, Certbot **standalone** cannot bind to 80.

### Option A — Stop the container using the ports (temporary)

```bash
docker ps
# Find the container on 0.0.0.0:80->80 (e.g. caddy)
docker stop caddy
sudo certbot certonly --standalone -d qtec.chishty.me
# After certs exist, start your stack (e.g. docker compose for this project).
# If you still need Caddy for other sites, reconfigure Caddy to not use 80/443 or use a different host.
```

### Option B — Use Caddy’s or Nginx’s existing TLS (advanced)

If you keep Caddy on 443, you can obtain certs with a **DNS** challenge or Caddy’s automatic HTTPS instead of Certbot standalone—out of scope for this repo’s default flow.

### Option C — Stop only for renewal

For `certbot renew` with standalone, stop whatever holds port 80 briefly, run renew, then start services again.

---

## `SSH_PRIVATE_KEY` (GitHub Actions → deploy to VM)

1. On **your laptop** (or wherever you generate keys):

   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/qtec_deploy -N ""
   ```

2. **Public key** on the **Azure VM** (as the user that will run deploy, e.g. `azureuser`):

   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

3. **Private key** for GitHub:
   - Copy the **private** key file content (e.g. `~/.ssh/qtec_deploy`):

     ```bash
     cat ~/.ssh/qtec_deploy
     ```

   - In GitHub: repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**
   - Name: `SSH_PRIVATE_KEY`
   - Value: entire private key including `-----BEGIN ... OPENSSH PRIVATE KEY-----` ... `-----END ...-----`

4. Also add secrets: `SERVER_IP` (VM public IP), `SERVER_USER` (e.g. `azureuser`).

---

## Container registry (GHCR)

The workflow uses the repository **`GITHUB_TOKEN`** with `permissions: packages: write` to push images to `ghcr.io`. You **do not** need a personal access token (`GHCR_TOKEN`) for CI.

Optional: If you ever switch to a PAT-based login, create a classic token with **`write:packages`** and store it as `GHCR_TOKEN`, then point `docker/login-action` at that secret instead of `github.token`.

---

## Quick reference: required Action secrets

| Secret            | Purpose                                      |
|-------------------|----------------------------------------------|
| `SSH_PRIVATE_KEY` | Private key for `ssh` to the VM              |
| `SERVER_IP`       | VM public IP                                 |
| `SERVER_USER`     | SSH login name                               |
