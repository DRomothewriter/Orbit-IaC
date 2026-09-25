# ==============================================================================
# ORBIT IAC - HOSTING FRONTEND (S3 PRIVADO + CLOUDFRONT CDN + OAC)
# ==============================================================================

# Bucket S3 privado para los artefactos estáticos compilados de Angular
resource "aws_s3_bucket" "frontend_static" {
  bucket = "${var.project_name}-frontend-static-${var.environment}"

  tags = {
    Name        = "${var.project_name}-frontend-static-${var.environment}"
    Purpose     = "Frontend Angular Static Assets Hosting"
    Environment = var.environment
  }
}

# Cifrado obligatorio en reposo con AES256 (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_static_encryption" {
  bucket = aws_s3_bucket.frontend_static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueo total de acceso público: el bucket permanece 100% privado
resource "aws_s3_bucket_public_access_block" "frontend_static_public_access" {
  bucket = aws_s3_bucket.frontend_static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin Access Control (OAC) de CloudFront para acceso seguro y autenticado a S3
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-frontend-oac-${var.environment}"
  description                       = "Origin Access Control para el bucket privado del frontend de Orbit"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Distribución global de CloudFront (CDN)
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [local.frontend_fqdn]

  origin {
    domain_name              = aws_s3_bucket.frontend_static.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend_static.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_static.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  # ----------------------------------------------------------------------------
  # SOPORTE PARA ANGULAR SPA ROUTING (HTML5 Deep Linking)
  # Redirige códigos 403 y 404 hacia /index.html con status HTTP 200
  # ----------------------------------------------------------------------------
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.frontend_cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${var.project_name}-frontend-distribution-${var.environment}"
    Environment = var.environment
  }
}

# Política de bucket que permite acceso de lectura EXCLUSIVAMENTE a CloudFront vía OAC
resource "aws_s3_bucket_policy" "frontend_static_oac_read" {
  bucket = aws_s3_bucket.frontend_static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend_static.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_static_public_access]
}
