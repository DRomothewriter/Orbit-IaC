terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend remoto en AWS S3 con bloqueo de estado concurrente vía DynamoDB.
  backend "s3" {
    bucket         = "orbit-terraform-state-us-east-2"
    key            = "orbit/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "orbit-terraform-locks"
    encrypt        = true
  }
}
