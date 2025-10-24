####################
# ALB Security Group
####################
resource "aws_security_group" "alb_sg" {
  name        = "${var.name_prefix}-alb-sg"
  vpc_id      = var.vpc_id
  description = "Allow HTTP from internet"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-alb-sg" }
}

####################
# Instance Security Group
####################
resource "aws_security_group" "instance_sg" {
  name        = "${var.name_prefix}-instance-sg"
  vpc_id      = var.vpc_id
  description = "Allow ALB - instances"

  ingress {
    from_port       = 9898
    to_port         = 9898
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB to container port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-instance-sg" }
}