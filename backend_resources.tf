# ==============================================================================
# S3 BUCKET PARA ALMACENAMIENTO DE ESTADO REMOTO DE TERRAFORM
# ==============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${var.aws_region}"

  # Previene la destrucción accidental del bucket que contiene el historial del estado
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-terraform-state-${var.aws_region}"
    Purpose     = "Terraform Remote State Storage"
    Environment = var.environment
  }
}

# Habilitar versionado obligatorio para mantener histórico y recuperación ante desastres
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado obligatorio en reposo con algoritmo AES256 (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueo total de acceso público para proteger secretos y topología del estado
resource "aws_s3_bucket_public_access_block" "terraform_state_public_access" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# DYNAMODB TABLE PARA BLOQUEO DE ESTADO CONCURRENTE (STATE LOCKING)
# ==============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-locks"
    Purpose     = "Terraform State Locking"
    Environment = var.environment
  }
}
