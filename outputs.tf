output "terraform_state_bucket_name" {
  description = "Nombre del bucket S3 configurado como backend remoto para el estado de Terraform"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_bucket_arn" {
  description = "ARN del bucket S3 del estado remoto de Terraform"
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_locks_dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB utilizada para state locking concurrente"
  value       = aws_dynamodb_table.terraform_locks.id
}

output "terraform_locks_dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB utilizada para state locking concurrente"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "primary_region" {
  description = "Región principal de AWS configurada para los recursos del proyecto"
  value       = var.aws_region
}

output "acm_certificate_region" {
  description = "Región requerida para certificados SSL de CloudFront (us-east-1)"
  value       = "us-east-1"
}
