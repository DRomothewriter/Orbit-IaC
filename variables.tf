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
