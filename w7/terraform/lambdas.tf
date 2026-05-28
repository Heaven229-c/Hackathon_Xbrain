# -----------------------------------------------------------------------------
# 4. LAMBDA FUNCTIONS
# -----------------------------------------------------------------------------

# --- 1. API Handler Lambda ---
data "archive_file" "api_handler_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/api-handler-lambda"
  output_path = "${path.module}/api-handler.zip"
}

resource "aws_lambda_function" "api_handler" {
  function_name    = "${local.resource_base_name}-api-handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.10"
  filename         = data.archive_file.api_handler_zip.output_path
  source_code_hash = data.archive_file.api_handler_zip.output_base64sha256
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      WORKSPACE_TABLE  = aws_dynamodb_table.workspaces.name
      DOCUMENT_TABLE   = aws_dynamodb_table.documents.name
      COMPANY_TABLE    = aws_dynamodb_table.companies.name
      USER_TABLE       = aws_dynamodb_table.users.name
      S3_BUCKET        = aws_s3_bucket.dochub_data.id
      BEDROCK_KB_ID    = aws_bedrockagent_knowledge_base.dochub_kb.id
      BEDROCK_DS_ID    = aws_bedrockagent_data_source.dochub_ds.data_source_id
      ALLOWED_ORIGIN   = local.api_cors_allowed_origin
      METRIC_NAMESPACE = local.metric_namespace
      DEMO_AUTH_SECRET = var.demo_auth_secret
    }
  }
}

# --- 2. Event Handler Lambda ---
data "archive_file" "event_handler_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/event-handler-lambda"
  output_path = "${path.module}/event-handler.zip"
}

resource "aws_lambda_function" "event_handler" {
  function_name    = "${local.resource_base_name}-event-handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.10"
  filename         = data.archive_file.event_handler_zip.output_path
  source_code_hash = data.archive_file.event_handler_zip.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DOCUMENT_TABLE   = aws_dynamodb_table.documents.name
      S3_BUCKET        = aws_s3_bucket.dochub_data.id
      BEDROCK_KB_ID    = aws_bedrockagent_knowledge_base.dochub_kb.id
      BEDROCK_DS_ID    = aws_bedrockagent_data_source.dochub_ds.data_source_id
      ALLOWED_ORIGIN   = local.api_cors_allowed_origin
      METRIC_NAMESPACE = local.metric_namespace
    }
  }
}
