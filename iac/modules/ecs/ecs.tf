############ ECS CLUSTER ################

resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ecs_cluster_name
}

################# Task Definition ####################

resource "aws_ecs_task_definition" "ecs_task_def" {
  family = var.task_definition.family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu       = var.task_definition.cpu
  memory    = var.task_definition.memory
  execution_role_arn   = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = var.task_definition.name
      image     = var.task_definition.image
      mountPoints = [
        {
          "sourceVolume": var.task_definition.volume_name,
          "containerPath": var.task_definition.volume_containerPath,
          "readOnly": false
        }
      ]
      portMappings = [
        {
          containerPort = var.task_definition.containerPort
          hostPort      = var.task_definition.hostPort
        }
      ]
      environment = [
    {
        name  = "CHROMA_PATH"
        value = var.task_definition.volume_containerPath
    }
      ]
      network_configuration = {
           subnets          = var.aws_alb.subnets
           security_groups  = [aws_security_group.ecs_task_sg.id]
           assign_public_ip = true
    }
      secrets = [
    {
        name      = "GROQ_API_KEY"
        valueFrom = var.secretsmanager_secret
    }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.aws_log_group.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
  volume {
    name      = var.task_definition.volume_name
    efs_volume_configuration {
        file_system_id     = var.task_definition.efs_file_system_id
        transit_encryption = "ENABLED"
    }
  }
}

########### LOG GROUP ###################

resource "aws_cloudwatch_log_group" "aws_log_group" {
  name = var.log_group
}

################# Task Execution Role and Policy ############

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "EcsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_role_policy" {
  name = "EcsTaskExecutionRolePolicy"
  role = aws_iam_role.ecs_task_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        Effect   = "Allow"
        Resource = "*"
      },
              {
            Sid =  "BasePermissions",
            Effect =  "Allow",
            Action = [
                "secretsmanager:GetSecretValue",
            ],
            Resource = var.secretsmanager_secret
        }
    ]
  })
}

########### alb sg ############

resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "alb sg for ecs"
  vpc_id      = var.vpc_id 
  ingress {

            from_port        = 80
            to_port          = 80
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
            }
  egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  tags = {
    Name = "alb_sg"
  }
}

############### load balancer #############

resource "aws_lb" "aws-alb" {
  name               = var.aws_alb.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.aws_alb.subnets

  enable_deletion_protection = true

}

resource "aws_lb_target_group" "alb_tg" {
  name        = var.alb_tg
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id 
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
}
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.aws-alb.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.alb_tg.arn
    }
}

############## Service ##############

resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_def.arn
  desired_count   = 1
  health_check_grace_period_seconds = 90
  capacity_provider_strategy  {
    capacity_provider = "FARGATE"
    weight            = 1
  }
  network_configuration {
    subnets          = var.aws_alb.subnets
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = true
}
  deployment_configuration {
    strategy = "ROLLING"
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.alb_tg.arn
    container_name   = var.task_definition.name
    container_port   = 8000
  }
  }

resource "aws_security_group" "ecs_task_sg" {
  name        = "ecs_task_sg"
  description = "ecs task sg for efs"
  vpc_id      = var.vpc_id 
  ingress {

            from_port        = 8000
            to_port          = 8000
            protocol         = "tcp"
            security_groups  = [aws_security_group.alb_sg.id]
            }
  egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
  tags = {
    Name = "ecs_task_sg"
  }
}
