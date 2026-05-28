variable "bedrock_kb_id" {
  description = "Knowledge Base ID created on Console"
  type        = string
  default     = ""
}

variable "bedrock_ds_id" {
  description = "Data Source ID created on Console"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region used for all regional resources."
  type        = string
  default     = "us-west-2"
}

variable "resource_name_prefix" {
  description = "Lowercase prefix used for AWS resource names to avoid collisions between learners."
  type        = string
  default     = "g5"

  validation {
    condition     = length(var.resource_name_prefix) <= 8 && can(regex("^[a-z]([a-z0-9-]{0,6}[a-z0-9])?$", lower(var.resource_name_prefix)))
    error_message = "resource_name_prefix must be 1-8 characters, start with a letter, end with a letter or number, and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "bedrock_model_id" {
  description = "Bedrock Model ID to use for inference"
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "bedrock_embedding_model_id" {
  description = "Bedrock embedding model ID used by the Knowledge Base."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "embedding_vector_dimension" {
  description = "Vector dimension for the selected embedding model."
  type        = number
  default     = 1024
}

variable "min_retrieval_score" {
  description = "Minimum Bedrock KB retrieval score accepted by the AI backend. Keep 0 for demo safety; increase after measuring retrieval quality."
  type        = number
  default     = 0
}

variable "ai_backend_image_tag" {
  description = "Docker image tag for the AI backend ECS task"
  type        = string
  default     = "latest"
}

variable "allowed_cors_origin" {
  description = "Browser origin allowed by API Gateway and Lambda responses. Defaults to the CloudFront frontend URL."
  type        = string
  default     = ""
}

variable "demo_auth_secret" {
  description = "Shared HMAC secret used by the demo login flow. Replace for each deployment."
  type        = string
  default     = "g5-dochub-demo-auth-secret"
  sensitive   = true
}

variable "demo_user_password" {
  description = "Initial password for seeded demo users. Replace for each deployment."
  type        = string
  default     = "123456"
  sensitive   = true
}

variable "additional_s3_cors_origins" {
  description = "Additional origins allowed to upload directly to the document S3 bucket, for example localhost during development."
  type        = list(string)
  default     = []
}

variable "opensearch_index_admin_arns" {
  description = "Additional IAM principal ARNs allowed to create/manage the OpenSearch Serverless index during deployment."
  type        = list(string)
  default     = []
}

locals {
  resource_name_prefix = lower(var.resource_name_prefix)
  resource_base_name   = "${local.resource_name_prefix}-dochub"
  metric_namespace     = "${local.resource_name_prefix}-DocHub"
  oss_collection_name  = "${local.resource_base_name}-ai-kb"
  oss_index_name       = "${local.resource_name_prefix}-bedrock-kb-index"
  embedding_model_arn  = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_embedding_model_id}"

  demo_companies = {
    company_a = "Company A"
    company_b = "Company B"
  }

  demo_users = {
    "admin@companya.test" = {
      tenant_id    = "company_a"
      company_name = "Company A"
      role         = "company_admin"
    }
    "member@companya.test" = {
      tenant_id    = "company_a"
      company_name = "Company A"
      role         = "member"
    }
    "admin@companyb.test" = {
      tenant_id    = "company_b"
      company_name = "Company B"
      role         = "company_admin"
    }
    "member@companyb.test" = {
      tenant_id    = "company_b"
      company_name = "Company B"
      role         = "member"
    }
  }

  api_cors_allowed_origin = var.allowed_cors_origin != "" ? var.allowed_cors_origin : "https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"
  s3_cors_allowed_origins = distinct(concat([local.api_cors_allowed_origin], var.additional_s3_cors_origins))
}
