#!/usr/bin/env bash
set -euo pipefail

cd /home/frappe/frappe-bench

# Variables de entorno con valores por defecto basados en tu config
SITE_NAME="${SITE_NAME:-site1.local}"
DB_HOST="${DB_HOST:?Falta DB_HOST}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_USERNAME="${DB_ROOT_USERNAME:-root}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:?Falta DB_ROOT_PASSWORD}"
REDIS_CACHE="${REDIS_CACHE:?Falta REDIS_CACHE}"
REDIS_QUEUE="${REDIS_QUEUE:?Falta REDIS_QUEUE}"

# 1. Configuración de conexiones globales
echo "==> Configurando bench globalmente"
bench set-config -g db_host "$DB_HOST"
bench set-config -gp db_port "$DB_PORT"
bench set-config -g redis_cache "$REDIS_CACHE"
bench set-config -g redis_queue "$REDIS_QUEUE"
bench set-config -g redis_socketio "$REDIS_QUEUE"

# 2. Crear site si no existe
if [ ! -f "sites/${SITE_NAME}/site_config.json" ]; then
  echo "==> Creando nuevo site: ${SITE_NAME} en ${DB_HOST}:${DB_PORT}"
  
  # Intentar crear el sitio
  # Nota: Usamos --db-port y --db-root-username para compatibilidad con Aiven
  bench new-site "$SITE_NAME" \
    --admin-password "${ADMIN_PASSWORD:-admin}" \
    --db-root-username "$DB_ROOT_USERNAME" \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --db-host "$DB_HOST" \
    --db-port "$DB_PORT" \
    --no-mariadb-socket \
    --install-app gestion_medica

  # 3. Configuración para Bases de Datos Externas (SSL)
  # Aiven requiere SSL. Frappe lo maneja a través de MariaDB client.
  echo "==> Configurando parámetros de seguridad de DB"
  bench --site "$SITE_NAME" set-config db_type "mariadb"

  # 4. Configurar S3 en el site_config.json si las variables existen
  if [ "${S3_ENABLE:-0}" == "1" ]; then
    echo "==> Configurando S3 para almacenamiento de archivos..."
    bench --site "$SITE_NAME" set-config s3_access_key "$S3_KEY"
    bench --site "$SITE_NAME" set-config s3_secret_key "$S3_SECRET"
    bench --site "$SITE_NAME" set-config s3_bucket "$S3_BUCKET"
    bench --site "$SITE_NAME" set-config s3_region "$S3_REGION"
    bench --site "$SITE_NAME" set-config endpoint_url "${S3_ENDPOINT:-https://s3.amazonaws.com}"
    bench --site "$SITE_NAME" set-config backup_setup_completed 1
  fi
else
  echo "==> El site ya existe, ejecutando migraciones..."
  bench --site "$SITE_NAME" migrate
fi

echo "==> Iniciando Procesos con Supervisord..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf