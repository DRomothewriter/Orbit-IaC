# Proveedor principal de AWS (us-east-2 - Ohio)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Proveedor alias para us-east-1 (N. Virginia)
# Requerido obligatoriamente por AWS para la emisión de certificados SSL/TLS con ACM
# asociados a distribuciones globales de CloudFront.
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = var.tags
  }
}
