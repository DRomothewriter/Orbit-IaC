variable "aws_region" {
  description = "Región principal de AWS donde se desplegarán los recursos de infraestructura de Orbit"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Entorno de ejecución de la infraestructura (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nombre base del proyecto utilizado como prefijo en la nomenclatura de recursos"
  type        = string
  default     = "orbit"
}

variable "domain_name" {
  description = "Dominio raíz del proyecto Orbit para DNS y certificados SSL/TLS"
  type        = string
  default     = "orbitapp.dev"
}

variable "tags" {
  description = "Etiquetas comunes aplicadas por defecto a todos los recursos gestionados por Terraform"
  type        = map(string)
  default = {
    Project   = "Orbit"
    ManagedBy = "Terraform"
  }
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para el backend (t3.small o t3.medium recomendado para Mediasoup)"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Tamaño en GiB del volumen EBS raíz (gp3) para la instancia EC2"
  type        = number
  default     = 30
}

variable "admin_ssh_cidr" {
  description = "Lista de bloques CIDR autorizados para acceso SSH (puerto 22). Vacío por defecto al usar AWS SSM"
  type        = list(string)
  default     = []
}

variable "cors_allowed_origins" {
  description = "Lista de orígenes permitidos por CORS para el bucket de almacenamiento multimedia"
  type        = list(string)
  default = [
    "http://localhost:4200",
    "https://orbitapp.dev",
    "https://*.orbitapp.dev",
    "https://orbit.diego-romo-dev.com"
  ]
}

variable "root_domain_name" {
  description = "Dominio raíz administrado en Route 53 (Hosted Zone)"
  type        = string
  default     = "diego-romo-dev.com"
}

variable "frontend_subdomain" {
  description = "Subdominio donde se alojará el cliente web de Orbit"
  type        = string
  default     = "orbit"
}

variable "backend_subdomain" {
  description = "Subdominio donde se expondrá la API y WebSockets del backend"
  type        = string
  default     = "api.orbit"
}

variable "create_route53_records" {
  description = "Indica si se deben crear los registros DNS en Route 53 de forma automatizada"
  type        = bool
  default     = true
}

variable "github_org_or_user" {
  description = "Usuario u organización de GitHub propietario de los repositorios de Orbit"
  type        = string
  default     = "DRomothewriter"
}

variable "github_repositories" {
  description = "Lista de nombres de repositorios autorizados para asumir el rol OIDC de despliegue"
  type        = list(string)
  default     = ["Orbit-Backend", "Orbit-Frontend", "Orbit-IaC"]
}

variable "ecr_image_retention_count" {
  description = "Cantidad máxima de imágenes Docker retenidas en ECR por la política de ciclo de vida"
  type        = number
  default     = 5
}




