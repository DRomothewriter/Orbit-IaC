# ==============================================================================
# ORBIT IAC - RED Y SUBNETS (DEFAULT VPC)
# ==============================================================================
# Se utiliza la Default VPC y sus subredes públicas para evitar el costo mensual
# recurrente de NAT Gateways (~$32/mes por gateway), permitiendo que la instancia
# EC2 tenga salida directa a internet y asociación con una Elastic IP pública.

data "aws_vpc" "default" {
  default = true
}

# Obtener todas las subredes públicas disponibles en la Default VPC
data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
