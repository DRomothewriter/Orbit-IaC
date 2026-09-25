# ==============================================================================
# ORBIT IAC - INSTANCIA EC2 DEL BACKEND Y ELASTIC IP
# ==============================================================================

# Consulta dinámica de la última AMI oficial de Ubuntu 24.04 LTS de Canonical
data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Instancia EC2 que hospeda los contenedores del Backend y Mediasoup
resource "aws_instance" "backend" {
  ami                  = data.aws_ami.ubuntu_24_04.id
  instance_type        = var.instance_type
  subnet_id            = data.aws_subnets.default_public.ids[0]
  iam_instance_profile = aws_iam_instance_profile.backend_instance_profile.name

  vpc_security_group_ids = [
    aws_security_group.backend_sg.id
  ]

  # Inyección del script de bootstrap automatizado (Docker, Docker Compose, SSM)
  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  # Configuración del disco raíz con cifrado EBS y volumen de alto rendimiento gp3
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name        = "${var.project_name}-backend-root-disk-${var.environment}"
      Environment = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-backend-instance-${var.environment}"
    Role        = "Backend-Mediasoup"
    Environment = var.environment
  }
}

# Dirección Elastic IP fija y persistente requerida para MEDIASOUP_ANNOUNCED_IP
resource "aws_eip" "backend_eip" {
  domain   = "vpc"
  instance = aws_instance.backend.id

  tags = {
    Name        = "${var.project_name}-backend-eip-${var.environment}"
    Purpose     = "Mediasoup Announced Public IP"
    Environment = var.environment
  }

  depends_on = [aws_instance.backend]
}
