# -----------------------------------------------------------------------------
# 9. ECS FARGATE (AI BACKEND)
# -----------------------------------------------------------------------------

# --- ECR (Docker Registry) ---
resource "aws_ecr_repository" "ai_backend" {
  name                 = "${local.resource_base_name}-ai-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

output "ai_backend_ecr_repository_url" {
  description = "ECR repository URL for the AI backend image"
  value       = aws_ecr_repository.ai_backend.repository_url
}

# --- ALB (Application Load Balancer) ---
# ALB nằm ở public subnet để có thể nhận traffic từ API Gateway
resource "aws_lb" "ecs_alb" {
  name               = "${local.resource_base_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "ecs_tg" {
  name        = "${local.resource_base_name}-ecs-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

# --- ECS Cluster & Service ---
resource "aws_ecs_cluster" "main" {
  name = "${local.resource_base_name}-cluster"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "${local.resource_base_name}-ai-backend-logs"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "ai_backend" {
  family                   = "${local.resource_base_name}-ai-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "${local.resource_base_name}-ai-backend"
    image     = "${aws_ecr_repository.ai_backend.repository_url}:${var.ai_backend_image_tag}"
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]
    environment = [
      { name = "AWS_REGION", value = var.aws_region },
      { name = "BEDROCK_KB_ID", value = aws_bedrockagent_knowledge_base.dochub_kb.id },
      { name = "BEDROCK_DS_ID", value = aws_bedrockagent_data_source.dochub_ds.data_source_id },
      { name = "BEDROCK_MODEL_ID", value = var.bedrock_model_id },
      { name = "MIN_RETRIEVAL_SCORE", value = tostring(var.min_retrieval_score) },
      { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.documents.name },
      { name = "WORKSPACE_TABLE", value = aws_dynamodb_table.workspaces.name },
      { name = "ALLOWED_ORIGINS", value = local.api_cors_allowed_origin },
      { name = "METRIC_NAMESPACE", value = local.metric_namespace },
      { name = "DEMO_AUTH_SECRET", value = var.demo_auth_secret }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "ai_backend" {
  name            = "${local.resource_base_name}-ai-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ai_backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  propagate_tags  = "SERVICE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "${local.resource_base_name}-ai-backend"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.ecs_listener]
}
