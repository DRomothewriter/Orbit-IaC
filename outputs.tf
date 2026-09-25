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

output "backend_public_ip" {
  description = "Dirección Elastic IP pública persistente asignada al backend (usada en MEDIASOUP_ANNOUNCED_IP)"
  value       = aws_eip.backend_eip.public_ip
}

output "backend_instance_id" {
  description = "Identificador de la instancia EC2 que hospeda el backend de Orbit"
  value       = aws_instance.backend.id
}

output "backend_security_group_id" {
  description = "ID del Security Group asociado al backend y a Mediasoup"
  value       = aws_security_group.backend_sg.id
}

output "backend_iam_role_arn" {
  description = "ARN del rol IAM asignado a la instancia EC2"
  value       = aws_iam_role.backend_ec2_role.arn
}

output "media_bucket_name" {
  description = "Nombre del bucket S3 para almacenamiento de avatares e imágenes"
  value       = aws_s3_bucket.media_storage.id
}

output "media_bucket_arn" {
  description = "ARN del bucket S3 de almacenamiento multimedia"
  value       = aws_s3_bucket.media_storage.arn
}

output "media_bucket_domain_name" {
  description = "Nombre de dominio regional de S3 para acceder a los archivos multimedia"
  value       = aws_s3_bucket.media_storage.bucket_regional_domain_name
}

output "frontend_bucket_name" {
  description = "Nombre del bucket S3 privado que hospeda los archivos estáticos de Angular"
  value       = aws_s3_bucket.frontend_static.id
}

output "frontend_bucket_arn" {
  description = "ARN del bucket S3 del frontend"
  value       = aws_s3_bucket.frontend_static.arn
}

output "cloudfront_distribution_id" {
  description = "Identificador único de la distribución de CloudFront"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "Nombre de dominio asignado por CloudFront (ej. d123456789.cloudfront.net)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_url" {
  description = "URL principal de acceso al frontend de Orbit"
  value       = "https://${local.frontend_fqdn}"
}

output "api_url" {
  description = "URL principal de acceso a la API del backend de Orbit"
  value       = "https://${local.backend_fqdn}"
}



