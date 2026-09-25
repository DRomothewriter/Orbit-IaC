# Orbit Infrastructure as Code (IaC)

Este repositorio contiene la definición de Infraestructura como Código (IaC) para la plataforma **Orbit**, administrada de forma reproducible, declarativa y segura mediante **Terraform**.

---

## 1. Arquitectura y Regiones

- **Región Primaria:** `us-east-2` (Ohio). Todos los recursos de cómputo, red, base de datos y backend residen en esta región.
- **Región Secundaria (Alias):** `us-east-1` (N. Virginia). Proveedor configurado obligatoriamente para emitir certificados SSL/TLS en AWS Certificate Manager (ACM) utilizados por Amazon CloudFront.
- **Almacenamiento de Estado Remoto:** AWS S3 (`orbit-terraform-state-us-east-2`) con:
  - Versionado habilitado para auditoría y recuperación ante desastres.
  - Cifrado en reposo obligatorio con `AES256` (SSE-S3).
  - Bloqueo total de acceso público (`Public Access Block`).
  - Protección de borrado accidental (`prevent_destroy = true`).
- **Bloqueo Concurrente (State Locking):** Amazon DynamoDB (`orbit-terraform-locks`) con clave de partición `LockID` y modo on-demand (`PAY_PER_REQUEST`).

---

## 2. Requisitos Previos

1. **Terraform CLI:** Versión `>= 1.5.0` instalada.
   ```bash
   terraform -version
   ```
2. **AWS CLI v2:** Configurado con credenciales válidas y permisos suficientes para provisionar recursos en AWS (S3, DynamoDB, etc.).
   ```bash
   aws sts get-caller-identity
   ```

---

## 3. Estructura del Repositorio

```text
Orbit-IaC/
├── .gitignore                  # Exclusión de estados locales, secretos y archivos temporales
├── versions.tf                 # Requisitos de versión, proveedores y bloque backend "s3"
├── providers.tf                # Configuración de proveedores AWS (us-east-2 y alias us-east-1)
├── variables.tf                # Declaración de variables configurables
├── backend_resources.tf        # Declaración de recursos para el backend remoto (S3 + DynamoDB)
├── network.tf                  # Resolución de Default VPC y subred pública
├── security_groups.tf          # Firewall para HTTP (80), HTTPS (443) y Mediasoup UDP (10000-10100)
├── iam.tf                      # Rol IAM, Instance Profile, políticas SSM y permisos S3 Media
├── user_data.sh                # Script de bootstrap con Docker, Docker Compose y SSM Agent
├── ec2.tf                      # Instancia EC2 Ubuntu 24.04, volumen cifrado gp3 y Elastic IP
├── media_storage.tf            # Bucket S3 de media (avatares, chat) con SSE-S3, CORS y lectura pública
├── frontend.tf                 # Hosting Angular S3 privado + CloudFront CDN + OAC + SPA routing
├── dns.tf                      # Registros Route 53 y certificado SSL ACM (us-east-1)
├── cicd_oidc.tf                # Registro ECR, proveedor OIDC GitHub y rol de despliegue IAM
├── docker/                     # Configuración de orquestación en producción
│   ├── docker-compose.prod.yml # Compose con backend (host mode), Nginx y Certbot
│   ├── nginx/                  # Configuración de Nginx con soporte para WebSockets y SSL
│   │   ├── nginx.conf
│   │   └── conf.d/orbit.conf
│   ├── scripts/init-ssl.sh     # Script bootstrap para certificados Let's Encrypt
│   └── .env.production.template# Plantilla de variables de producción
├── outputs.tf                  # Salidas exportadas (IP pública, URLs de frontend y backend, ARNs)

├── terraform.tfvars.example    # Plantilla de variables para entornos
├── tests/                      # Suite de pruebas unitarias automatizadas (TDD) con terraform test
│   └── infrastructure.tftest.hcl
├── SCALING_STRATEGY.md         # Hoja de ruta arquitectónica para escalado a 10,000+ usuarios
└── README.md                   # Documentación de arquitectura y operaciones
```



---

## 4. Arquitectura de Cómputo y Optimización de Costos

### ¿Por qué NO usamos un Load Balancer (ALB) ni Kubernetes (EKS)?
1. **Incompatibilidad Técnica de ALB con Mediasoup:** El Application Load Balancer de AWS opera únicamente en capa 7 (HTTP/HTTPS) y **no soporta tráfico UDP**. Mediasoup (WebRTC SFU) requiere tráfico UDP bidireccional en el rango `10000-10100` para los flujos multimedia RTP/RTCP. Usar un Network Load Balancer (NLB) o ALB encarecería la factura en más de **$20 - $45 USD mensuales**.
2. **Cero Sobrecosto de Orquestación:** Evitamos Kubernetes administrado (AWS EKS cobra $73 USD/mes solo por el plano de control). En su lugar, el backend corre en contenedores con **Docker Compose** orquestado sobre una única instancia EC2 (`t3.small` / `t3.medium`).
3. **Terminación SSL y Proxy Inverso:** Un contenedor ligero de **Nginx** recibe el tráfico en los puertos `80` y `443` con certificados SSL/TLS automáticos de Let's Encrypt, redirigiendo a Node.js interna y limpiamente.
4. **Elastic IP Dedicada:** La dirección IP pública estática se asigna a la EC2 sin intermediarios, permitiendo que la variable `MEDIASOUP_ANNOUNCED_IP` resuelva con latencia mínima.

### Almacenamiento Multimedia y Seguridad IAM (Sin Secretos en `.env`)
- **Bucket S3 para Media (`media_storage.tf`):** Los avatares e imágenes subidas mediante `multer-s3` se almacenan en un bucket dedicado con cifrado `AES256` (SSE-S3), reglas CORS configuradas para el frontend y lectura pública de objetos (`s3:GetObject`).
- **Autenticación Vía IAM Instance Profile:** El backend de Node.js no requiere variables `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY` estáticas en `.env`. La política `s3_media_access` adjunta al rol de la EC2 le otorga permisos automáticos y rotativos de menor privilegio (`s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`, `s3:ListBucket`).

### Distribución Global del Frontend (Angular SPA) y DNS
- **Bucket S3 Privado y CloudFront OAC (`frontend.tf`):** Los artefactos estáticos compilados de Angular (`dist/orbit-frontend/browser`) residen en un bucket 100% privado. El acceso se restringe exclusivamente a CloudFront mediante **Origin Access Control (OAC)** con firma criptográfica SigV4.
- **Soporte Nativo de Angular SPA Routing:** Respuestas de error HTTP `403` y `404` se capturan en CloudFront y se redirigen automáticamente a `/index.html` con status `200`, permitiendo que el enrutador de Angular gestione rutas profundas sin errores al recargar.
- **Certificados SSL y DNS (`dns.tf`):** Certificado SSL emitido y validado automáticamente en ACM (`us-east-1`). En Route 53, `orbit.diego-romo-dev.com` se enlaza mediante un registro Alias `A` a CloudFront y `api.orbit.diego-romo-dev.com` mediante registro `A` a la Elastic IP del backend.

### Automatización de CI/CD con ECR y OIDC (Cero Llaves en GitHub Secrets)
- **Registro de Contenedores ECR (`cicd_oidc.tf`):** Repositorio privado `orbit-backend` con escaneo de vulnerabilidades `scan_on_push = true` y política de ciclo de vida que conserva únicamente las últimas 5 imágenes para controlar costes.
- **Autenticación OIDC de GitHub Actions:** Proveedor OpenID Connect federado con rol IAM de menor privilegio asumible exclusivamente por los repositorios de Orbit. Permite:
  1. Build y push de imágenes a ECR sin almacenar credenciales `AWS_ACCESS_KEY_ID` estáticas.
  2. Despliegue estático de Angular a S3 e invalidación de caché en CloudFront.
  3. Ejecución de despliegues en la EC2 mediante **AWS SSM SendCommand** (`AWS-RunShellScript`).

### Orquestación en Producción (`docker/`)
- **Backend en `network_mode: host`:** Configuración esencial para Mediasoup SFU; elimina la sobrecarga del puente de red y permite que los 100 puertos multimedia UDP (`10000-10100`) se vinculen directamente a la interfaz física de la máquina.
- **Nginx Reverse Proxy con Soporte WebSockets:** Termina el tráfico SSL con certificados de Let's Encrypt para `api.orbit.diego-romo-dev.com`, reenviando las peticiones a `127.0.0.1:3000` con encabezados `Upgrade` y `Connection` para mantener los canales de Socket.io en streaming constante sin degradación.
- **Certbot Automático:** Contenedor auxiliar que renueva los certificados SSL cada 12 horas de forma transparente.
- **Inicialización:** Script `docker/scripts/init-ssl.sh` para solicitar los certificados iniciales y recargar Nginx en el primer despliegue.


---

## 5. Guía de Bootstrap (Primer Despliegue del Backend)

Cuando el bucket S3 y la tabla DynamoDB aún no existen en AWS, Terraform no puede conectarse al backend remoto inmediatamente. El proceso de bootstrapping se realiza en tres pasos:

### Paso 1: Inicialización Local
Inicializar Terraform omitiendo la conexión al backend remoto para descargar los proveedores necesarios:
```bash
terraform init -backend=false
```

### Paso 2: Crear el Bucket S3 y la Tabla DynamoDB
Aprovisionar los recursos de backend definidos en `backend_resources.tf`:
```bash
# Copiar las variables de ejemplo si aún no tienes terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# Desplegar los recursos de estado
terraform apply -target=aws_s3_bucket.terraform_state -target=aws_s3_bucket_versioning.terraform_state_versioning -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state_encryption -target=aws_s3_bucket_public_access_block.terraform_state_public_access -target=aws_dynamodb_table.terraform_locks
```

### Paso 3: Migrar el Estado al Backend Remoto
Una vez que el bucket y la tabla existen en AWS, inicializar el backend remoto y migrar el estado local a S3:
```bash
terraform init -migrate-state
```
Cuando Terraform pregunte si deseas copiar el estado existente al nuevo backend S3, responde `yes`.

---

## 6. Comandos de Operación Diaria

- **Formatear código:**
  ```bash
  terraform fmt
  ```
- **Validar sintaxis y referencias:**
  ```bash
  terraform validate
  ```
- **Previsualizar cambios:**
  ```bash
  terraform plan
  ```
- **Aplicar cambios:**
  ```bash
  terraform apply
  ```
- **Ejecutar suite de pruebas unitarias (TDD):**
  ```bash
  terraform test
  ```

---

## 7. Estrategia de Escalado y Hoja de Ruta

Para consultar la evolución arquitectónica proyectada hacia multi-región, desacoplamiento del SFU con Mediasoup PipeTransports, Redis ElastiCache y balanceadores NLB/ALB para más de 10,000 usuarios concurrentes, revisa el documento dedicado:
👉 [**Estrategia de Escalado de Infraestructura (`SCALING_STRATEGY.md`)**](SCALING_STRATEGY.md).

