# ===========================================
# # ALB and Target Group(TG)
# ===========================================
resource "aws_lb" "demo-alb" {
  name               = var.app_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demo-lb-sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_listener" "demo-alb-listener" {
  load_balancer_arn = aws_lb.demo-alb.id
  port              = "80"
  protocol          = "HTTP"


  default_action {
    target_group_arn = aws_lb_target_group.demo-alb-tg.id
    type             = "forward"
  }

  depends_on = [ aws_lb_target_group.demo-alb-tg ]
}

resource "aws_lb_target_group" "demo-alb-tg" {
    name = var.app_name
    port = var.app_port
    protocol = "HTTP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
    depends_on = [ aws_lb.demo-alb ]
    load_balancing_algorithm_type = "least_outstanding_requests"
}

# ===========================================
# Security Group
# ===========================================
resource "aws_security_group" "demo-lb-sg" {
    name = "${var.app_name}-lb-sg"
    vpc_id = module.vpc.vpc_id
    tags = {
        Name = "${var.app_name}-lb-sg"
    }

    ingress {
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
}

resource "aws_security_group" "demo" {
    name = "${var.app_name}-sg"
    vpc_id = module.vpc.vpc_id
    tags = {
        Name = var.app_name
    }

    ingress {
        description = "TLS from VPC"
        from_port   = var.app_port
        to_port     = var.app_port
        protocol    = "tcp"
        security_groups = [aws_security_group.demo-lb-sg.id]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_ecr_repository" "demo" {
  name                 = var.app_name
  image_tag_mutability = "MUTABLE"
}

resource "null_resource" "exec_cmd" {
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ap-northeast-1 | sudo docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com;sudo docker build -t ${var.app_name} ./docker/;sudo docker tag ${var.app_name}:latest ${var.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/${var.app_name}:latest;sudo docker push ${var.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/${var.app_name}:latest"
    # interpreter = []
  }

  depends_on = [
    aws_ecr_repository.demo
  ]
}

# ===========================================
# ECS Cluster and Fargate
# ===========================================
resource "aws_ecs_cluster" "demo" {
  name = var.app_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "demo" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.task_execution.arn
  container_definitions    = <<DEFINITION
  [
    {
      "image": "${var.account_id}.dkr.ecr.ap-northeast-1.amazonaws.com/${var.app_name}:latest",
      "name": "${var.app_name}",
      "networkMode": "awsvpc",
      "portMappings": [
        {
          "containerPort": ${var.app_port},
          "hostPort": ${var.app_port}
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${var.app_name}",
          "awslogs-region": "ap-northeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
  DEFINITION

  depends_on = [
    aws_ecr_repository.demo,
    null_resource.exec_cmd,
  ]
}

resource "aws_ecs_service" "demo" {
  name            = var.app_name
  cluster         = aws_ecs_cluster.demo.id
  task_definition = aws_ecs_task_definition.demo.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 30

  network_configuration {
    security_groups = [aws_security_group.demo.id]
    subnets         = module.vpc.private_subnets
    assign_public_ip= false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.demo-alb-tg.id
    container_name   = var.app_name
    container_port   = var.app_port
  }

  depends_on = [
    aws_ecs_task_definition.demo
  ]
}

resource "aws_cloudwatch_log_group" "demo" {
  name = "/ecs/${var.app_name}"
  retention_in_days = 7
}
