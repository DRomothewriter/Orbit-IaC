# ==============================================================================
# ORBIT IAC - DNS (ROUTE 53) Y CERTIFICADOS SSL (ACM EN US-EAST-1)
# ==============================================================================

locals {
  frontend_fqdn = "${var.frontend_subdomain}.${var.root_domain_name}"
  backend_fqdn  = "${var.backend_subdomain}.${var.root_domain_name}"
}

# Consulta de la Hosted Zone principal en Amazon Route 53
data "aws_route53_zone" "primary" {
  name         = var.root_domain_name
  private_zone = false
}

# Certificado SSL/TLS en AWS Certificate Manager
# Requerido obligatoriamente en la región us-east-1 para distribuciones de CloudFront
resource "aws_acm_certificate" "frontend_cert" {
  provider          = aws.us-east-1
  domain_name       = local.frontend_fqdn
  validation_method = "DNS"

  tags = {
    Name        = "${var.project_name}-frontend-cert-${var.environment}"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Registros DNS de validación CNAME generados automáticamente en Route 53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    "${local.frontend_fqdn}" = {
      name   = tolist(aws_acm_certificate.frontend_cert.domain_validation_options)[0].resource_record_name
      record = tolist(aws_acm_certificate.frontend_cert.domain_validation_options)[0].resource_record_value
      type   = tolist(aws_acm_certificate.frontend_cert.domain_validation_options)[0].resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}


# Validación del certificado ACM contra los registros DNS
resource "aws_acm_certificate_validation" "frontend_cert" {
  provider                = aws.us-east-1
  certificate_arn         = aws_acm_certificate.frontend_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ------------------------------------------------------------------------------
# REGISTROS DNS DE APLICACIÓN EN ROUTE 53
# ------------------------------------------------------------------------------

# Registro Alias tipo A para el frontend apuntando a la distribución de CloudFront
resource "aws_route53_record" "frontend" {
  zone_id         = data.aws_route53_zone.primary.zone_id
  name            = local.frontend_fqdn
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

# Registro tipo A para la API del backend apuntando a la Elastic IP de la EC2
resource "aws_route53_record" "backend_api" {
  zone_id         = data.aws_route53_zone.primary.zone_id
  name            = local.backend_fqdn
  type            = "A"
  ttl             = 300
  records         = [aws_eip.backend_eip.public_ip]
  allow_overwrite = true
}
