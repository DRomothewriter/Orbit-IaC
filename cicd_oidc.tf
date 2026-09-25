# ==============================================================================
# ORBIT IAC - REPOSITORIO ECR Y AUTENTICACIÓN OIDC PARA GITHUB ACTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# REPOSITORIO PRIVADO ECR PARA IMÁGENES DOCKER DEL BACKEND
# ------------------------------------------------------------------------------

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-backend"
    Purpose     = "Container Image Registry for Orbit Backend and Mediasoup"
    Environment = var.environment
  }
}

# Política de ciclo de vida para controlar costes de almacenamiento en ECR
resource "aws_ecr_lifecycle_policy" "backend_lifecycle" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retener únicamente las últimas ${var.ecr_image_retention_count} imágenes Docker"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# PROVEEDOR OPENID CONNECT (OIDC) PARA GITHUB ACTIONS
# ------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c5878692eee48e5690a8231cccf2f7b82836a58"
  ]

  tags = {
    Name        = "${var.project_name}-github-oidc-provider"
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# ROL IAM ASUMIBLE POR GITHUB ACTIONS (SIN SECRETOS ESTÁTICOS)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_actions" {
  name        = "${var.project_name}-github-actions-role-${var.environment}"
  description = "Rol IAM asumible por GitHub Actions vía OIDC para despliegue automatizado sin credenciales estáticas"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.github_repositories : "repo:${var.github_org_or_user}/${repo}:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-github-actions-role-${var.environment}"
    Environment = var.environment
  }
}

# Política de permisos de menor privilegio para pipelines de CI/CD
resource "aws_iam_policy" "github_actions_policy" {
  name        = "${var.project_name}-github-actions-policy-${var.environment}"
  description = "Permisos de menor privilegio para build, push a ECR, deploy S3/CloudFront y despliegue EC2 vía SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Autenticación y push de imágenes a ECR
      {
        Sid      = "AllowECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "AllowECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.backend.arn
      },
      # 2. Despliegue estático de frontend a S3 e invalidación en CloudFront
      {
        Sid    = "AllowFrontendS3Sync"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.frontend_static.arn,
          "${aws_s3_bucket.frontend_static.arn}/*"
        ]
      },
      {
        Sid    = "AllowCloudFrontInvalidation"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation"
        ]
        Resource = aws_cloudfront_distribution.frontend.arn
      },
      # 3. Despliegue automatizado en EC2 mediante AWS SSM SendCommand
      {
        Sid    = "AllowSSMRunCommand"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand"
        ]
        Resource = [
          aws_instance.backend.arn,
          "arn:aws:ssm:${var.aws_region}:*:document/AWS-RunShellScript"
        ]
      },
      {
        Sid    = "AllowSSMCommandStatus"
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_attachment" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}
