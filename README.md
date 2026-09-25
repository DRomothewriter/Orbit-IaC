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
├── outputs.tf                  # Salidas y metadatos exportados
├── terraform.tfvars.example    # Plantilla de variables para entornos
└── README.md                   # Documentación de arquitectura y operaciones
```

---

## 4. Guía de Bootstrap (Primer Despliegue del Backend)

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

## 5. Comandos de Operación Diaria

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
