#!/usr/bin/env bash
set -euo pipefail

cd /home/frappe/frappe-bench

# Recomendado: usa un nombre fijo de site (ej: tu dominio)
SITE_NAME="${SITE_NAME:-site1.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_HOST="${DB_HOST:?DB_HOST requerido}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD requerido}"
REDIS_CACHE="${REDIS_CACHE:?REDIS_CACHE requerido}"
REDIS_QUEUE="${REDIS_QUEUE:?REDIS_QUEUE requerido}"
SOCKETIO_PORT="${SOCKETIO_PORT:-9000}"

# Asegura apps.txt (útil para tooling de frappe)
ls -1 apps > sites/apps.txt || true

# Config global (como configurator en frappe_docker)
bench set-config -g db_host "$DB_HOST"
bench set-config -gp db_port "$DB_PORT"
bench set-config -g redis_cache "$REDIS_CACHE"
bench set-config -g redis_queue "$REDIS_QUEUE"
bench set-config -gp socketio_port "$SOCKETIO_PORT"

# Crear site si no existe aún
if [ ! -f "sites/${SITE_NAME}/site_config.json" ]; then
  echo "==> Creando site ${SITE_NAME}"
  bench new-site "$SITE_NAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --db-root-username root \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --db-host "$DB_HOST" \
    --db-port "$DB_PORT" \
    --no-mariadb-socket

  echo "==> Instalando app gestion_medica"
  bench --site "$SITE_NAME" install-app gestion_medica
fi

echo "==> Migrando"
bench --site "$SITE_NAME" migrate

echo "==> Arrancando procesos"
exec /usr/bin/supervisord -n