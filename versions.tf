terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto en AWS S3 con bloqueo de estado concurrente vía DynamoDB.
  # NOTA DE BOOTSTRAP:
  # Para el primer despliegue antes de que existan el bucket S3 y la tabla DynamoDB:
  # 1. Comentar temporalmente este bloque 'backend "s3"' o inicializar con 'terraform init -backend=false'.
  # 2. Aplicar la creación de los recursos de backend: 'terraform apply -target=aws_s3_bucket.terraform_state -target=aws_dynamodb_table.terraform_locks'.
  # 3. Descomentar este bloque y migrar el estado local a S3: 'terraform init -migrate-state'.
  backend "s3" {
    bucket         = "orbit-terraform-state-us-east-2"
    key            = "orbit/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "orbit-terraform-locks"
    encrypt        = true
  }
}
