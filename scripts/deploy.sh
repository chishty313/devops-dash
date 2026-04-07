#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/opt/qtec"
STATE_FILE="${STATE_DIR}/.active_color"
UPSTREAM_FILE="./nginx/conf.d/backend_upstream.conf"
COMPOSE_FILE="./docker-compose.yml"

mkdir -p "${STATE_DIR}"

if [[ -f "${STATE_FILE}" ]]; then
  ACTIVE_COLOR="$(cat "${STATE_FILE}")"
else
  ACTIVE_COLOR="blue"
fi

if [[ "${ACTIVE_COLOR}" == "blue" ]]; then
  INACTIVE_COLOR="green"
else
  INACTIVE_COLOR="blue"
fi

echo "Active color: ${ACTIVE_COLOR}"
echo "Deploying inactive color: ${INACTIVE_COLOR}"

docker compose -f "${COMPOSE_FILE}" pull "backend_${INACTIVE_COLOR}" frontend
docker compose -f "${COMPOSE_FILE}" up -d mongodb prometheus grafana frontend
docker compose -f "${COMPOSE_FILE}" up -d "backend_${INACTIVE_COLOR}"

echo "Running health checks against backend_${INACTIVE_COLOR}..."
for i in {1..20}; do
  if docker compose -f "${COMPOSE_FILE}" exec -T "backend_${INACTIVE_COLOR}" wget -qO- http://localhost:3000/api/status >/dev/null; then
    echo "Health check passed"
    break
  fi
  if [[ "${i}" -eq 20 ]]; then
    echo "Health check failed after 60 seconds"
    exit 1
  fi
  sleep 3
done

cat > "${UPSTREAM_FILE}" <<EOF
upstream backend {
  least_conn;
  server backend_${INACTIVE_COLOR}:3000 max_fails=3 fail_timeout=10s;
  keepalive 32;
}
EOF

docker compose -f "${COMPOSE_FILE}" up -d nginx
docker compose -f "${COMPOSE_FILE}" exec -T nginx nginx -s reload

docker compose -f "${COMPOSE_FILE}" stop "backend_${ACTIVE_COLOR}" || true

echo "${INACTIVE_COLOR}" > "${STATE_FILE}"
echo "Deployment completed. Active color is now: ${INACTIVE_COLOR}"
