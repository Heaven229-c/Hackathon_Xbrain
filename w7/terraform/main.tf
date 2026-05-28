provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "${local.resource_name_prefix}-group5-hackathon"
      Owner       = local.resource_name_prefix
      Team        = local.resource_name_prefix
      Environment = "hackathon"
      Application = local.resource_base_name
      NamePrefix  = local.resource_base_name
    }
  }
}

# -----------------------------------------------------------------------------
# 1. DynamoDB tables
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "workspaces" {
  name         = "${local.resource_base_name}-workspaces"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "workspace_id"

  attribute {
    name = "workspace_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "documents" {
  name         = "${local.resource_base_name}-documents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "companies" {
  name         = "${local.resource_base_name}-companies"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenant_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table" "users" {
  name         = "${local.resource_base_name}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_dynamodb_table_item" "demo_companies" {
  for_each   = local.demo_companies
  table_name = aws_dynamodb_table.companies.name
  hash_key   = aws_dynamodb_table.companies.hash_key

  item = jsonencode({
    tenant_id = { S = each.key }
    name      = { S = each.value }
    status    = { S = "active" }
    is_demo   = { BOOL = true }
  })
}

resource "aws_dynamodb_table_item" "demo_users" {
  for_each   = local.demo_users
  table_name = aws_dynamodb_table.users.name
  hash_key   = aws_dynamodb_table.users.hash_key

  item = jsonencode({
    email         = { S = each.key }
    password_hash = { S = sha256(var.demo_user_password) }
    tenant_id     = { S = each.value.tenant_id }
    company_name  = { S = each.value.company_name }
    role          = { S = each.value.role }
    status        = { S = "active" }
    is_demo       = { BOOL = true }
  })
}

# -----------------------------------------------------------------------------
# 2. S3 document bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "dochub_data" {
  bucket_prefix = "${local.resource_base_name}-data-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "dochub_data_block" {
  bucket                  = aws_s3_bucket.dochub_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "dochub_data_ownership" {
  bucket = aws_s3_bucket.dochub_data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dochub_data_encryption" {
  bucket = aws_s3_bucket.dochub_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "dochub_data_versioning" {
  bucket = aws_s3_bucket.dochub_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "dochub_data_lifecycle" {
  bucket = aws_s3_bucket.dochub_data.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_policy" "dochub_data_policy" {
  bucket = aws_s3_bucket.dochub_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.dochub_data.arn,
          "${aws_s3_bucket.dochub_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_cors_configuration" "dochub_data_cors" {
  bucket = aws_s3_bucket.dochub_data.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = local.s3_cors_allowed_origins
    max_age_seconds = 3000
  }
}

# -----------------------------------------------------------------------------
# 3. IAM roles and policies
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${local.resource_base_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_app_policy" {
  name        = "${local.resource_base_name}-lambda-app-policy"
  description = "Allow DocHub Lambda functions to access application data resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.workspaces.arn,
          aws_dynamodb_table.documents.arn,
          aws_dynamodb_table.companies.arn,
          aws_dynamodb_table.users.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.dochub_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = local.metric_namespace
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_app_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_app_policy.arn
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.resource_base_name}-ecs-execution-role"

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

resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${local.resource_base_name}-ecs-task-role"

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

resource "aws_iam_policy" "ecs_bedrock_policy" {
  name        = "${local.resource_base_name}-ecs-bedrock-policy"
  description = "Allow the AI backend task to retrieve and generate answers with Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.workspaces.arn,
          aws_dynamodb_table.documents.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:RetrieveAndGenerate",
          "bedrock:Retrieve"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.dochub_data.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = local.metric_namespace
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_bedrock_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_bedrock_policy.arn
}
