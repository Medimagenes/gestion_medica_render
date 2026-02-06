# Usa las imágenes/estructura de frappe_docker como referencia.
# Lo más estable es construir con el Containerfile de layered.
FROM debian:bookworm-slim

ARG FRAPPE_BRANCH=version-15
ARG APPS_JSON_BASE64

# Dependencias mínimas (en un proyecto real, conviene basarse en frappe_docker images)
RUN apt-get update && apt-get install -y \
  git curl bash python3 python3-venv python3-pip nodejs npm supervisor nginx \
  && rm -rf /var/lib/apt/lists/*

# Instala bench
RUN pip3 install frappe-bench

# Usuario frappe
RUN useradd -m -s /bin/bash frappe
USER frappe
WORKDIR /home/frappe

# Decode apps.json
RUN echo "$APPS_JSON_BASE64" | base64 -d > /home/frappe/apps.json

# Crea bench e instala apps definidas en apps.json
RUN bench init frappe-bench --frappe-branch ${FRAPPE_BRANCH} --apps_path=/home/frappe/apps.json
WORKDIR /home/frappe/frappe-bench

# Copia configs y entrypoint
USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Persistencia: en Render montarás disco en /home/frappe/frappe-bench/sites
EXPOSE 8080
CMD ["/entrypoint.sh"]