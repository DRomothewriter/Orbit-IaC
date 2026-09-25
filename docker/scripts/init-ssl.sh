#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ORBIT BACKEND - SCRIPT DE INICIALIZACIÓN SSL (LET'S ENCRYPT / CERTBOT)
# ==============================================================================
# Resuelve el bootstrap de certificados SSL para Nginx en la primera ejecución:
# 1. Genera certificados temporales para permitir el arranque de Nginx.
# 2. Inicia Nginx y expone el puerto 80 con el reto ACME.
# 3. Solicita los certificados reales a Let's Encrypt mediante Certbot.
# 4. Recarga Nginx con los certificados válidos.

DOMAIN="api.orbit.diego-romo-dev.com"
EMAIL="diego.romo.dev@gmail.com" # Cambiar por el email del administrador
RSA_KEY_SIZE=4096
DATA_PATH="./certbot"

if [ ! -e "$DATA_PATH/conf/options-ssl-nginx.conf" ] || [ ! -e "$DATA_PATH/conf/ssl-dhparams.pem" ]; then
  echo "[Init-SSL] Descargando parámetros recomendados de TLS..."
  mkdir -p "$DATA_PATH/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$DATA_PATH/conf/options-ssl-nginx.conf" || true
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$DATA_PATH/conf/ssl-dhparams.pem" || true
fi

echo "[Init-SSL] Creando certificado temporal para $DOMAIN..."
CERT_PATH="$DATA_PATH/conf/live/$DOMAIN"
mkdir -p "$CERT_PATH"
mkdir -p "$DATA_PATH/www"

if [ ! -f "$CERT_PATH/privkey.pem" ]; then
  openssl req -x509 -nodes -newkey rsa:$RSA_KEY_SIZE -days 1 \
    -keyout "$CERT_PATH/privkey.pem" \
    -out "$CERT_PATH/fullchain.pem" \
    -subj "/CN=localhost"
fi

echo "[Init-SSL] Levantando Nginx para validación ACME..."
docker compose -f docker-compose.prod.yml up --force-recreate -d nginx

echo "[Init-SSL] Eliminando certificado temporal..."
rm -rf "$CERT_PATH"

echo "[Init-SSL] Solicitando certificado real a Let's Encrypt para $DOMAIN..."
docker compose -f docker-compose.prod.yml run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    --email $EMAIL \
    -d $DOMAIN \
    --rsa-key-size $RSA_KEY_SIZE \
    --agree-tos \
    --force-renewal \
    --non-interactive" certbot

echo "[Init-SSL] Recargando Nginx con el nuevo certificado..."
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

echo "[Init-SSL] Certificado SSL instalado exitosamente para $DOMAIN."
