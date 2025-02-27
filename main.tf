data "aws_availability_zones" "available" {
  state = "available"
}

# Network Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "medhq-prism-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "medhq-prism-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "medhq-prism-private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "medhq-prism-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "medhq-prism-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Lambda Functions
# resource "aws_lambda_function" "notification" {
#   filename      = "notification.zip"
#   function_name = "medhq-prism-results-notification"
#   role          = aws_iam_role.lambda_role.arn
#   handler       = "index.handler"
#   runtime       = "python3.11"
# }

# resource "aws_lambda_function" "retrieval" {
#   filename      = "retrieval.zip"
#   function_name = "medhq-prism-results-retrieval"
#   role          = aws_iam_role.lambda_role.arn
#   handler       = "index.handler"
#   runtime       = "python3.11"
# }

# resource "aws_lambda_function" "ingestion" {
#   filename      = "ingestion.zip"
#   function_name = "medhq-prism-image-ingestion"
#   role          = aws_iam_role.lambda_role.arn
#   handler       = "index.handler"
#   runtime       = "python3.11"
# }

# # S3 Buckets
# resource "aws_s3_bucket" "results" {
#   bucket = "medhq-prism-results"
# }

# resource "aws_s3_bucket_versioning" "results" {
#   bucket = aws_s3_bucket.results.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket" "input" {
#   bucket = "medhq-prism-input-image"
# }

# resource "aws_s3_bucket_versioning" "input" {
#   bucket = aws_s3_bucket.input.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket" "initial" {
#   bucket = "medhq-prism-initial-load"
# }

# resource "aws_s3_bucket_versioning" "initial" {
#   bucket = aws_s3_bucket.initial.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# SQS FIFO Queue
# resource "aws_sqs_queue" "queue" {
#   name       = "medhq-prism-queue.fifo"
#   fifo_queue = true
# }

# SNS Topic
resource "aws_sns_topic" "email" {
  name = "medhq-prism-email-topic"
}

# Cognito

# resource "aws_cognito_user_pool" "main" {
#   name = "medhq-prism-user-pool"
# }

# ECS & ECR
# resource "aws_ecr_repository" "main" {
#   name = "medhq-prism-ml-model"
# }

resource "aws_ecr_repository" "main-api" {
  name = "medhq-prism-api"
}

# resource "aws_ecr_repository" "qa-api" {
#   name = "medhq-prism-qa-api-model"
# }

# resource "aws_ecr_repository" "image-recog-api" {
#   name = "medhq-prism-page-recognition-worker"
# }

resource "aws_ecs_cluster" "main" {
  name = "medhq-prism-cluster"
}

# # EFS
# resource "aws_efs_file_system" "main" {
#   creation_token = "medhq-prism-model-storage"
# }

# resource "aws_efs_mount_target" "main" {
#   count           = 2
#   file_system_id  = aws_efs_file_system.main.id
#   subnet_id       = aws_subnet.private[count.index].id
#   security_groups = [aws_security_group.efs.id]
# }

# # ECS Task Definition
# resource "aws_ecs_task_definition" "main" {
#   family = "medhq-prism-ml-task"
#   requires_compatibilities = ["FARGATE"]
#   network_mode = "awsvpc"
#   cpu = 256
#   memory = 512
#   execution_role_arn = aws_iam_role.ecs_execution_role.arn
#   task_role_arn = aws_iam_role.ecs_task_role.arn

#   container_definitions = jsonencode([
#     {
#       name = "medhq-prism-ml-container"
#       image = "${aws_ecr_repository.main.repository_url}:latest"
#       essential = true
#       mountPoints = [
#         {
#           sourceVolume = "efs-volume"
#           containerPath = "/mnt/efs"
#           readOnly = false
#         }
#       ]
#     }
#   ])

#   volume {
#     name = "efs-volume"
#     efs_volume_configuration {
#       file_system_id = aws_efs_file_system.main.id
#       root_directory = "/"
#     }
#   }
# }

# # ECS Service
# resource "aws_ecs_service" "main" {
#   name = "medhq-prism-ml-service"
#   cluster = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.main.arn
#   desired_count = 1
#   launch_type = "FARGATE"

#   network_configuration {
#     subnets = aws_subnet.private[*].id
#     security_groups = [aws_security_group.ecs.id]
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.api.arn
#     container_name   = "medhq-prism-ml-container"
#     container_port   = 8000
#   }
# }

# ECS Task Definition
resource "aws_ecs_task_definition" "main-api" {
  family                   = "medhq-prism-api-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "medhq-prism-api-container"
      image     = "${aws_ecr_repository.main-api.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      # healthCheck = {
      #   command = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
      #   interval = 30
      #   timeout = 5
      #   retries = 3
      #   startPeriod = 60
      # }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/medhq-prism-api"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
          "awslogs-create-group"  = "true"
        }
      }
    }
  ])
}

# resource "aws_ecs_task_definition" "qa-api" {
#   family                   = "medhq-prism-qa-api-task"
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = 256
#   memory                   = 512
#   execution_role_arn       = aws_iam_role.ecs_execution_role.arn
#   task_role_arn            = aws_iam_role.ecs_task_role.arn

#   container_definitions = jsonencode([
#     {
#       name      = "medhq-prism-qa-api-container"
#       image     = "${aws_ecr_repository.qa-api.repository_url}:latest"
#       essential = true
#       portMappings = [
#         {
#           containerPort = 8000
#           hostPort      = 8000
#           protocol      = "tcp"
#         }
#       ]
#       # healthCheck = {
#       #   command = ["CMD-SHELL", "curl -f http://localhost/ || exit 1"]
#       #   interval = 30
#       #   timeout = 5
#       #   retries = 3
#       #   startPeriod = 60
#       # }
#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           "awslogs-group"         = "/ecs/medhq-prism-qa-api"
#           "awslogs-region"        = "us-east-1"
#           "awslogs-stream-prefix" = "ecs"
#           "awslogs-create-group"  = "true"
#         }
#       }
#     }
#   ])
# }

# ECS Service
# resource "aws_ecs_service" "main-api" {
#   name            = "medhq-prism-api-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.main-api.arn
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = aws_subnet.public[*].id
#     security_groups  = [aws_security_group.ecs.id]
#     assign_public_ip = true
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.api.arn
#     container_name   = "medhq-prism-api-container"
#     container_port   = 8000
#   }

#   lifecycle {
#     ignore_changes = [task_definition]
#   }
# }


# resource "aws_ecs_service" "qa-api" {
#   name            = "medhq-prism-qa-api-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.qa-api.arn
#   desired_count   = 0
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = aws_subnet.public[*].id
#     security_groups  = [aws_security_group.ecs.id]
#     assign_public_ip = true
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.qa-api.arn
#     container_name   = "medhq-prism-qa-api-container"
#     container_port   = 8000
#   }

#   # lifecycle {
#   #   ignore_changes = [ task_definition ]
#   # }
# }

# resource "aws_ecs_service" "page-recog-service" {
#   name            = "medhq-prism-page-recognition-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = "arn:aws:ecs:us-east-1:008971672549:task-definition/medhq-prism-page-recognition-task:9"
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = aws_subnet.public[*].id
#     security_groups  = [aws_security_group.ecs.id]
#     assign_public_ip = true
#   }

#   lifecycle {
#     ignore_changes = all
#   }

# }

# resource "aws_ecs_service" "g702-summary-service" {
#   name            = "medhq-prism-g702-summary-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = "arn:aws:ecs:us-east-1:008971672549:task-definition/medhq-prism-g702-summary-task:1"
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = aws_subnet.public[*].id
#     security_groups  = [aws_security_group.ecs.id]
#     assign_public_ip = true
#   }

#   # lifecycle {
#   #   ignore_changes = all
#   # }

# }

# ECS Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "medhq-prism-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name = "medhq-prism-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "medhq-prism-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "*"
        ]
      }
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "sqs:SendMessage",
      #     "sqs:ReceiveMessage",
      #     "sqs:DeleteMessage",
      #     "sqs:GetQueueAttributes"
      #   ]
      #   Resource = aws_sqs_queue.queue.arn
      # },
      # {
      #   Effect = "Allow"
      #   Action = [
      #     "elasticfilesystem:ClientMount",
      #     "elasticfilesystem:ClientWrite"
      #   ]
      #   Resource = aws_efs_file_system.main.arn
      # }
    ]
  })

  lifecycle {
    ignore_changes = all
  }
}

# Security Groups
resource "aws_security_group" "ecs" {
  name   = "medhq-prism-ecs-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "medhq-prism-ecs-sg"
  }
}

# resource "aws_security_group" "efs" {
#   name   = "medhq-prism-efs-sg"
#   vpc_id = aws_vpc.main.id

#   ingress {
#     from_port       = 2049
#     to_port         = 2049
#     protocol        = "tcp"
#     security_groups = [aws_security_group.ecs.id]
#   }

#   tags = {
#     Name = "medhq-prism-efs-sg"
#   }
# }


# Lambda Role
# resource "aws_iam_role" "lambda_role" {
#   name = "medhq-prism-lambda-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# Lambda Basic Execution Policy
# resource "aws_iam_role_policy_attachment" "lambda_basic" {
#   role       = aws_iam_role.lambda_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

# # Lambda S3 Access Policy
# resource "aws_iam_role_policy" "lambda_s3" {
#   name = "medhq-prism-lambda-s3-policy"
#   role = aws_iam_role.lambda_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:ListBucket"
#         ]
#         Resource = [
#           aws_s3_bucket.results.arn,
#           "${aws_s3_bucket.results.arn}/*",
#           aws_s3_bucket.input.arn,
#           "${aws_s3_bucket.input.arn}/*",
#           aws_s3_bucket.initial.arn,
#           "${aws_s3_bucket.initial.arn}/*"
#         ]
#       }
#     ]
#   })
# }

# Lambda SQS Access Policy
# resource "aws_iam_role_policy" "lambda_sqs" {
#   name = "medhq-prism-lambda-sqs-policy"
#   role = aws_iam_role.lambda_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       # {
#       #   Effect = "Allow"
#       #   Action = [
#       #     "sqs:SendMessage",
#       #     "sqs:ReceiveMessage",
#       #     "sqs:DeleteMessage",
#       #     "sqs:GetQueueAttributes"
#       #   ]
#       #   Resource = aws_sqs_queue.queue.arn
#       # }
#     ]
#   })

#   lifecycle {
#     ignore_changes = all
#   }
# }

# # Lambda SNS Access Policy
# resource "aws_iam_role_policy" "lambda_sns" {
#   name = "medhq-prism-lambda-sns-policy"
#   role = aws_iam_role.lambda_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "sns:Publish"
#         ]
#         Resource = aws_sns_topic.email.arn
#       }
#     ]
#   })
# }


# Cognito User Pool Client
# resource "aws_cognito_user_pool_client" "client" {
#   name         = "medhq-prism-app-client"
#   user_pool_id = aws_cognito_user_pool.main.id

#   explicit_auth_flows = [
#     "ALLOW_USER_PASSWORD_AUTH",
#     "ALLOW_REFRESH_TOKEN_AUTH"
#   ]
# }

# Lambda Permissions
# resource "aws_lambda_permission" "retrieval_api" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.retrieval.function_name
#   principal     = "apigateway.amazonaws.com"
# }

# resource "aws_lambda_permission" "ingestion_api" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.ingestion.function_name
#   principal     = "apigateway.amazonaws.com"
# }


# Application Load Balancer
resource "aws_lb" "main" {
  name               = "medhq-prism-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  idle_timeout = 300
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name   = "medhq-prism-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
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

# Target Groups
resource "aws_lb_target_group" "api" {
  name        = "medhq-prism-api-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled           = true
    healthy_threshold = 2
    interval          = 30
    timeout           = 5
    path              = "/health"
    port              = "8000"
    protocol          = "HTTP"
    matcher           = "200"
  }
}


# resource "aws_lb_target_group" "qa-api" {
#   name        = "medhq-prism-qa-api-tg"
#   port        = 8000
#   protocol    = "HTTP"
#   vpc_id      = aws_vpc.main.id
#   target_type = "ip"

#   health_check {
#     enabled           = true
#     healthy_threshold = 2
#     interval          = 30
#     timeout           = 5
#     path              = "/health/"
#     port              = "8000"
#     protocol          = "HTTP"
#     matcher           = "200"
#   }
# }

# resource "aws_lb_target_group" "ml" {
#   name        = "medhq-prism-ml-tg"
#   port        = 8000
#   protocol    = "HTTP"
#   vpc_id      = aws_vpc.main.id
#   target_type = "ip"

#   health_check {
#     enabled             = true
#     healthy_threshold   = 2
#     interval           = 30
#     timeout            = 5
#     path               = "/"
#     port               = "traffic-port"
#     protocol           = "HTTP"
#     matcher            = "200"
#   }
# }

# Listeners
# data "aws_acm_certificate" "dev_cert" {
#   domain      = "dev.api.medhq-prism-ai.com"
#   types       = ["AMAZON_ISSUED"]
#   most_recent = true
# }

# data "aws_acm_certificate" "qa-api-cert" {
#   domain      = "qa.api.medhq-prism-ai.com"
#   types       = ["AMAZON_ISSUED"]
#   most_recent = true
# }

resource "aws_lb_listener" "medhq-prism-api" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  # ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  # certificate_arn   = data.aws_acm_certificate.dev_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# resource "aws_lb_listener" "qa-api" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "8443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = data.aws_acm_certificate.qa-api-cert.arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.qa-api.arn
#   }
# }

# resource "aws_lb_listener" "ml" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "8000"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.ml.arn
#   }
# }

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/medhq-prism-api"
  retention_in_days = 30

  tags = {
    Name = "medhq-prism-api-logs"
  }
}

# resource "aws_cloudwatch_log_group" "ecs_worker_logs" {
#   name              = "/ecs/medhq-prism-worker"
#   retention_in_days = 30

#   tags = {
#     Name = "/ecs/medhq-prism-worker"
#   }
# }


# resource "aws_cloudwatch_log_group" "ecs_qa_api_logs" {
#   name              = "/ecs/medhq-prism-qa-api"
#   retention_in_days = 30

#   tags = {
#     Name = "medhq-prism-qa-api-logs"
#   }
# }

# Add ECR permissions to ECS execution role
resource "aws_iam_role_policy_attachment" "ecs_ecr_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


resource "aws_iam_role_policy" "ecs_cloudwatch_policy" {
  name = "medhq-prism-ecs-cloudwatch-policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "-1"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs.id
}
