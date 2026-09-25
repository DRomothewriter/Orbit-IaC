# ==============================================================================
# ORBIT IAC - SECURITY GROUP PARA EL BACKEND Y MEDIASOUP
# ==============================================================================

resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-backend-sg-${var.environment}"
  description = "Reglas de firewall para backend Orbit (HTTP, HTTPS, Mediasoup UDP y SSM)"
  vpc_id      = data.aws_vpc.default.id

  # ----------------------------------------------------------------------------
  # INGRESS RULES
  # ----------------------------------------------------------------------------

  # Puerto 80 (HTTP): Acceso web público y validaciones ACME Let's Encrypt
  ingress {
    description = "HTTP public ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto 443 (HTTPS): Acceso web seguro y terminación SSL con Nginx
  ingress {
    description = "HTTPS public ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Rango UDP 10000-10100: Tráfico multimedia RTP/RTCP para Mediasoup (WebRTC SFU)
  ingress {
    description = "Mediasoup WebRTC RTP/RTCP UDP media range"
    from_port   = 10000
    to_port     = 10100
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Puerto 22 (SSH): Opcional y restringido a la IP del administrador si se especifica
  dynamic "ingress" {
    for_each = length(var.admin_ssh_cidr) > 0 ? [1] : []
    content {
      description = "SSH restricted administrator ingress"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.admin_ssh_cidr
    }
  }

  # ----------------------------------------------------------------------------
  # EGRESS RULES
  # ----------------------------------------------------------------------------

  # Salida irrestricta a internet para paquetes del sistema operativo, Docker Hub, ECR y SSM
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-backend-sg-${var.environment}"
    Environment = var.environment
  }
}
