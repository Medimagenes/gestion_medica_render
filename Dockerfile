# Usa las imágenes/estructura de frappe_docker como referencia.
FROM debian:bookworm-slim

ARG FRAPPE_BRANCH=version-15

# Dependencias del sistema y de construcción (Build Essentials + Python libs + MariaDB client conf)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    bash \
    python3 \
    python3-dev \
    python3-venv \
    python3-pip \
    python3-setuptools \
    build-essential \
    libffi-dev \
    libssl-dev \
    default-libmysqlclient-dev \
    nodejs \
    npm \
    supervisor \
    redis-server \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Instala yarn (opcional, pero útil para algunos assets)
RUN npm install -g yarn

# Instala frappe-bench ignorando restricción de sistema (entorno docker)
RUN pip3 install frappe-bench --break-system-packages

# Usuario frappe
RUN useradd -m -s /bin/bash frappe

USER frappe
WORKDIR /home/frappe

# Copia apps.json directamente
COPY --chown=frappe:frappe apps.json /home/frappe/apps.json

# Configura git para frappe (necesario para bench init/clones)
RUN git config --global user.email "frappe@example.com" && \
    git config --global user.name "frappe"

# Inicializa bench e instala apps
# Usamos --skip-redis-config-generation para evitar errores de conexión a redis en build
# Si bench init falla, mostramos el log si existe
RUN bench init frappe-bench \
    --frappe-branch ${FRAPPE_BRANCH} \
    --apps_path=/home/frappe/apps.json \
    --skip-redis-config-generation \
    --verbose

WORKDIR /home/frappe/frappe-bench

# Instalar dependencias de aplicaciones (si apps.json trajo la app, instalamos sus reqs)
RUN ./env/bin/pip install -e apps/visits

# Copia configs y entrypoint
USER root
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN chown frappe:frappe /entrypoint.sh

USER frappe

# Puerto expuesto para Render (Render asigna puerto dinámico o busca 80/443/8080/etc)
EXPOSE 8080

CMD ["/entrypoint.sh"]