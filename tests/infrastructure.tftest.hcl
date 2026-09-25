# ==============================================================================
# ORBIT IAC - PRUEBAS DE INFRAESTRUCTURA (TERRAFORM TEST TDD)
# ==============================================================================
# Ejecuta aserciones automáticas en memoria mediante 'command = plan'
# sin necesidad de aprovisionar infraestructura real en AWS.

# Mock del proveedor AWS para pruebas unitarias sin dependencias externas
mock_provider "aws" {}

mock_provider "aws" {
  alias = "us-east-1"
}

# Mock de variables para el entorno de test
variables {
  environment  = "dev"
  project_name = "orbit"
  aws_region   = "us-east-2"
}

override_data {
  target = data.aws_subnets.default_public
  values = {
    ids = ["subnet-0123456789abcdef0"]
  }
}

override_data {
  target = data.aws_ami.ubuntu_24_04
  values = {
    id = "ami-0123456789abcdef0"
  }
}

override_data {
  target = data.aws_route53_zone.primary
  values = {
    zone_id = "Z0123456789ABCDEF"
    name    = "diego-romo-dev.com"
  }
}

override_resource {
  target = aws_acm_certificate.frontend_cert
  values = {
    arn         = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
    domain_name = "orbit.diego-romo-dev.com"
    domain_validation_options = [
      {
        domain_name           = "orbit.diego-romo-dev.com"
        resource_record_name  = "_a79865eb4cd1a6ab990a45779b4e0b96.orbit.diego-romo-dev.com."
        resource_record_type  = "CNAME"
        resource_record_value = "_x2.acm-validations.aws."
      }
    ]
  }
}





run "verify_security_group_rules" {
  command = plan

  assert {
    condition     = aws_security_group.backend_sg.name == "orbit-backend-sg-dev"
    error_message = "El nombre del Security Group no coincide con la convención de nomenclatura"
  }

  assert {
    condition     = length([for r in aws_security_group.backend_sg.ingress : r if r.from_port == 80 && r.to_port == 80]) == 1
    error_message = "El puerto HTTP 80 debe estar explícitamente configurado como regla de entrada"
  }

  assert {
    condition     = length([for r in aws_security_group.backend_sg.ingress : r if r.from_port == 443 && r.to_port == 443]) == 1
    error_message = "El puerto HTTPS 443 debe estar explícitamente configurado como regla de entrada"
  }

  assert {
    condition     = length([for r in aws_security_group.backend_sg.ingress : r if r.from_port == 10000 && r.to_port == 10100 && r.protocol == "udp"]) == 1
    error_message = "El rango UDP 10000-10100 para Mediasoup debe estar configurado como regla de entrada"
  }
}

run "verify_ec2_and_storage_defaults" {
  command = plan

  assert {
    condition     = aws_instance.backend.instance_type == "t3.small"
    error_message = "El tipo de instancia EC2 por defecto debe ser t3.small"
  }

  assert {
    condition     = aws_instance.backend.root_block_device[0].volume_size == 30
    error_message = "El tamaño por defecto del volumen raíz debe ser 30 GiB"
  }

  assert {
    condition     = aws_instance.backend.root_block_device[0].encrypted == true
    error_message = "El volumen raíz de la EC2 debe tener cifrado habilitado"
  }
}

run "verify_backend_resources" {
  command = plan

  assert {
    condition     = aws_s3_bucket.terraform_state.bucket == "orbit-terraform-state-us-east-2"
    error_message = "El nombre del bucket de estado de Terraform no coincide con el formato esperado"
  }

  assert {
    condition     = aws_dynamodb_table.terraform_locks.name == "orbit-terraform-locks"
    error_message = "El nombre de la tabla DynamoDB para locking no coincide con el formato esperado"
  }

  assert {
    condition     = aws_dynamodb_table.terraform_locks.hash_key == "LockID"
    error_message = "La partition key de la tabla DynamoDB debe ser obligatoriamente 'LockID'"
  }
}

run "verify_media_storage_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket.media_storage.bucket == "orbit-media-storage-dev"
    error_message = "El bucket de almacenamiento multimedia debe nombrarse orbit-media-storage-dev"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.media_storage_encryption.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "El bucket de almacenamiento multimedia debe estar cifrado con algoritmo AES256"
  }

  assert {
    condition     = contains(one(aws_s3_bucket_cors_configuration.media_storage_cors.cors_rule).allowed_methods, "GET") && contains(one(aws_s3_bucket_cors_configuration.media_storage_cors.cors_rule).allowed_methods, "PUT") && contains(one(aws_s3_bucket_cors_configuration.media_storage_cors.cors_rule).allowed_methods, "POST")
    error_message = "Las reglas CORS deben permitir los métodos GET, PUT y POST"
  }
}


run "verify_backend_media_iam_permissions" {
  command = plan

  assert {
    condition     = aws_iam_policy.s3_media_access.name == "orbit-backend-s3-media-dev"
    error_message = "La política IAM de acceso a media debe llamarse orbit-backend-s3-media-dev"
  }
}

run "verify_frontend_storage_and_oac" {
  command = plan

  assert {
    condition     = aws_s3_bucket.frontend_static.bucket == "orbit-frontend-static-dev"
    error_message = "El bucket de frontend debe llamarse orbit-frontend-static-dev"
  }

  assert {
    condition     = aws_cloudfront_origin_access_control.frontend_oac.name == "orbit-frontend-oac-dev"
    error_message = "El OAC de CloudFront debe llamarse orbit-frontend-oac-dev"
  }
}

run "verify_cloudfront_distribution_and_spa_routing" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.frontend.default_root_object == "index.html"
    error_message = "El default_root_object de CloudFront debe ser index.html"
  }

  assert {
    condition     = length([for e in aws_cloudfront_distribution.frontend.custom_error_response : e if e.error_code == 403 && e.response_code == 200 && e.response_page_path == "/index.html"]) == 1
    error_message = "CloudFront debe redirigir el error 403 a /index.html con código 200 para Angular SPA"
  }

  assert {
    condition     = length([for e in aws_cloudfront_distribution.frontend.custom_error_response : e if e.error_code == 404 && e.response_code == 200 && e.response_page_path == "/index.html"]) == 1
    error_message = "CloudFront debe redirigir el error 404 a /index.html con código 200 para Angular SPA"
  }
}

run "verify_dns_and_certificates" {
  command = plan

  assert {
    condition     = aws_acm_certificate.frontend_cert.domain_name == "orbit.diego-romo-dev.com"
    error_message = "El certificado ACM debe ser emitido para orbit.diego-romo-dev.com"
  }

  assert {
    condition     = aws_route53_record.frontend.name == "orbit.diego-romo-dev.com"
    error_message = "El registro DNS del frontend debe ser orbit.diego-romo-dev.com"
  }

  assert {
    condition     = aws_route53_record.backend_api.name == "api.orbit.diego-romo-dev.com"
    error_message = "El registro DNS del backend debe ser api.orbit.diego-romo-dev.com"
  }
}


