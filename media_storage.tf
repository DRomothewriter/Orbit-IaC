# ==============================================================================
# ORBIT IAC - S3 MEDIA BUCKET PARA AVATARES E IMÁGENES DE CHAT
# ==============================================================================

resource "aws_s3_bucket" "media_storage" {
  bucket = "${var.project_name}-media-storage-${var.environment}"

  tags = {
    Name        = "${var.project_name}-media-storage-${var.environment}"
    Purpose     = "Media Storage (Avatars and Chat Images)"
    Environment = var.environment
  }
}

# Cifrado obligatorio en reposo con AES256 (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "media_storage_encryption" {
  bucket = aws_s3_bucket.media_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Configuración de CORS para subida directa y visualización desde orígenes autorizados
resource "aws_s3_bucket_cors_configuration" "media_storage_cors" {
  bucket = aws_s3_bucket.media_storage.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "HEAD", "DELETE"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Configuración selectiva de Public Access Block:
# Se bloquean ACLs heredadas, pero se permite la política de bucket para lectura pública de objetos.
resource "aws_s3_bucket_public_access_block" "media_storage_public_access" {
  bucket = aws_s3_bucket.media_storage.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# Política de bucket que permite lectura pública (GetObject) de los archivos multimedia
resource "aws_s3_bucket_policy" "media_storage_public_read" {
  bucket = aws_s3_bucket.media_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicReadObjects"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.media_storage.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.media_storage_public_access]
}
