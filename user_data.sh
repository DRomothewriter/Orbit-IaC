#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# ORBIT BACKEND - EC2 BOOTSTRAP SCRIPT (USER_DATA)
# ==============================================================================
# Registra todo el output en /var/log/orbit_bootstrap.log
exec > >(tee -a /var/log/orbit_bootstrap.log) 2>&1

echo "[Orbit Bootstrap] Iniciando aprovisionamiento en $(date)"

# 1. Actualización de repositorios y paquetes base
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  htop \
  jq \
  unzip \
  software-properties-common

# 2. Instalación de Docker CE y Docker Compose Plugin (Repositorio oficial)
echo "[Orbit Bootstrap] Configurando repositorio oficial de Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# 3. Habilitar servicio Docker y agregar usuario 'ubuntu' al grupo
systemctl enable --now docker
usermod -aG docker ubuntu

# 4. Instalación y verificación de AWS SSM Agent y AWS CLI v2
echo "[Orbit Bootstrap] Asegurando instalación y arranque de Amazon SSM Agent..."
snap install amazon-ssm-agent --classic || true
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true

echo "[Orbit Bootstrap] Instalando AWS CLI v2..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# 5. Verificación de versiones instaladas
docker --version
docker compose version
aws --version

# 6. Preparación del directorio de orquestación para producción (/opt/orbit)
echo "[Orbit Bootstrap] Creando estructura de directorios en /opt/orbit..."
mkdir -p /opt/orbit/nginx/conf.d
mkdir -p /opt/orbit/certbot/conf
mkdir -p /opt/orbit/certbot/www
mkdir -p /opt/orbit/scripts

# Crear archivo marcador de docker-compose.prod.yml para despliegue
touch /opt/orbit/docker-compose.prod.yml

chown -R ubuntu:ubuntu /opt/orbit
chmod -R 755 /opt/orbit

echo "[Orbit Bootstrap] Aprovisionamiento completado exitosamente en $(date)"

