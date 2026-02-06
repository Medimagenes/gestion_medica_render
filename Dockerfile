FROM debian:bookworm-slim

ARG FRAPPE_BRANCH=version-15

# Evitar prompts de apt
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    python3 \
    python3-dev \
    python3-venv \
    python3-pip \
    build-essential \
    libffi-dev \
    libssl-dev \
    default-libmysqlclient-dev \
    libmariadb-dev-compat \
    libmariadb-dev \
    nodejs \
    npm \
    supervisor \
    redis-server \
    cron \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g yarn
RUN pip3 install frappe-bench --break-system-packages

RUN useradd -m -s /bin/bash frappe
USER frappe
WORKDIR /home/frappe

# Configuración de Apps
COPY --chown=frappe:frappe apps.json /home/frappe/apps.json

RUN git config --global user.email "frappe@example.com" && \
    git config --global user.name "frappe"

# Inicialización de Bench (sin crear site aún)
RUN bench init frappe-bench \
    --frappe-branch ${FRAPPE_BRANCH} \
    --apps_path=/home/frappe/apps.json \
    --skip-redis-config-generation \
    --no-backups \
    --verbose

WORKDIR /home/frappe/frappe-bench

# Instalar dependencias adicionales si es necesario
# Nota: La app se llama 'gestion_medica' según tu estructura de carpetas
RUN ./env/bin/pip install --upgrade pip

USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && chown frappe:frappe /entrypoint.sh

# Asegurar permisos del directorio sites (donde se monta el volumen)
RUN mkdir -p /home/frappe/frappe-bench/sites && chown -R frappe:frappe /home/frappe/frappe-bench/sites

USER frappe
EXPOSE 8080
CMD ["/entrypoint.sh"]