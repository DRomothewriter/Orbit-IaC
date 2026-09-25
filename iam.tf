# ==============================================================================
# ORBIT IAC - IAM ROLE E INSTANCE PROFILE PARA EC2 Y AWS SSM
# ==============================================================================

# Rol asumido por la instancia EC2
resource "aws_iam_role" "backend_ec2_role" {
  name        = "${var.project_name}-backend-ec2-role-${var.environment}"
  description = "Rol IAM para la instancia EC2 del backend con acceso a SSM Session Manager y Parameter Store"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-backend-ec2-role-${var.environment}"
    Environment = var.environment
  }
}

# Política gestionada de AWS para habilitar SSM Session Manager (acceso SSH-free seguro)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.backend_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política de lectura para AWS SSM Parameter Store
resource "aws_iam_policy" "parameter_store_read" {
  name        = "${var.project_name}-parameter-store-read-${var.environment}"
  description = "Permite a la instancia EC2 leer secretos y configuraciones desde SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadOrbitParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "parameter_store_attachment" {
  role       = aws_iam_role.backend_ec2_role.name
  policy_arn = aws_iam_policy.parameter_store_read.arn
}

# Instance profile asignado directamente a la instancia EC2
resource "aws_iam_instance_profile" "backend_instance_profile" {
  name = "${var.project_name}-backend-instance-profile-${var.environment}"
  role = aws_iam_role.backend_ec2_role.name

  tags = {
    Name        = "${var.project_name}-backend-instance-profile-${var.environment}"
    Environment = var.environment
  }
}

# Política IAM de menor privilegio para acceso al bucket S3 de almacenamiento multimedia (multer-s3)
resource "aws_iam_policy" "s3_media_access" {
  name        = "${var.project_name}-backend-s3-media-${var.environment}"
  description = "Permite a la instancia EC2 subir, leer y eliminar avatares e imágenes en S3 sin credenciales estáticas"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListMediaBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.media_storage.arn
      },
      {
        Sid    = "AllowManageMediaObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.media_storage.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_media_attachment" {
  role       = aws_iam_role.backend_ec2_role.name
  policy_arn = aws_iam_policy.s3_media_access.arn
}

