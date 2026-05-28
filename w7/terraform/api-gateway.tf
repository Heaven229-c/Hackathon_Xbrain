# -----------------------------------------------------------------------------
# 5. API GATEWAY (REST API) — Cửa ngõ HTTP cho Frontend gọi Lambda
# -----------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "dochub_api" {
  name        = "${local.resource_base_name}-api"
  description = "DocHub AI REST API"
}

# --- /auth/login ---
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_rest_api.dochub_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "auth_login" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "login"
}

resource "aws_api_gateway_resource" "auth_accounts" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "accounts"
}

resource "aws_api_gateway_method" "auth_login_post" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.auth_login.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "auth_accounts_get" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.auth_accounts.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "auth_login_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.auth_login.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_login_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.auth_login.id
  http_method = aws_api_gateway_method.auth_login_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_login_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.auth_login.id
  http_method = aws_api_gateway_method.auth_login_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_login_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.auth_login.id
  http_method = aws_api_gateway_method.auth_login_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.auth_login_options]
}

# --- /auth/accounts ---
resource "aws_api_gateway_method" "auth_accounts_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.auth_accounts.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_accounts_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.auth_accounts.id
  http_method = aws_api_gateway_method.auth_accounts_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_accounts_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.auth_accounts.id
  http_method = aws_api_gateway_method.auth_accounts_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "auth_accounts_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.auth_accounts.id
  http_method = aws_api_gateway_method.auth_accounts_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.auth_accounts_options]
}

# --- /companies/register, /companies/current and /companies/users ---
resource "aws_api_gateway_resource" "companies" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_rest_api.dochub_api.root_resource_id
  path_part   = "companies"
}

resource "aws_api_gateway_resource" "companies_register" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_resource.companies.id
  path_part   = "register"
}

resource "aws_api_gateway_resource" "companies_current" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_resource.companies.id
  path_part   = "current"
}

resource "aws_api_gateway_resource" "companies_users" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_resource.companies.id
  path_part   = "users"
}

resource "aws_api_gateway_method" "companies_current_get" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.companies_current.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "companies_register_post" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.companies_register.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "companies_users_post" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.companies_users.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "companies_users_delete" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.companies_users.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "companies_register_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.companies_register.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "companies_current_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.companies_current.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "companies_users_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.companies_users.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "companies_current_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_current.id
  http_method = aws_api_gateway_method.companies_current_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "companies_register_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_register.id
  http_method = aws_api_gateway_method.companies_register_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "companies_users_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_users.id
  http_method = aws_api_gateway_method.companies_users_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "companies_current_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_current.id
  http_method = aws_api_gateway_method.companies_current_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "companies_register_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_register.id
  http_method = aws_api_gateway_method.companies_register_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "companies_users_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_users.id
  http_method = aws_api_gateway_method.companies_users_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "companies_current_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_current.id
  http_method = aws_api_gateway_method.companies_current_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.companies_current_options]
}

resource "aws_api_gateway_integration_response" "companies_register_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_register.id
  http_method = aws_api_gateway_method.companies_register_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.companies_register_options]
}

resource "aws_api_gateway_integration_response" "companies_users_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.companies_users.id
  http_method = aws_api_gateway_method.companies_users_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.companies_users_options]
}

# --- /workspaces ---
resource "aws_api_gateway_resource" "workspaces" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_rest_api.dochub_api.root_resource_id
  path_part   = "workspaces"
}

resource "aws_api_gateway_method" "workspaces_get" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.workspaces.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "workspaces_post" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.workspaces.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "workspaces_delete" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.workspaces.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# CORS OPTIONS for /workspaces
resource "aws_api_gateway_method" "workspaces_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.workspaces.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "workspaces_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.workspaces.id
  http_method = aws_api_gateway_method.workspaces_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "workspaces_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.workspaces.id
  http_method = aws_api_gateway_method.workspaces_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "workspaces_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.workspaces.id
  http_method = aws_api_gateway_method.workspaces_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.workspaces_options]
}

# --- /documents ---
resource "aws_api_gateway_resource" "documents" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_rest_api.dochub_api.root_resource_id
  path_part   = "documents"
}

resource "aws_api_gateway_method" "documents_get" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.documents.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "documents_delete" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.documents.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# CORS OPTIONS for /documents
resource "aws_api_gateway_method" "documents_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.documents.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "documents_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.documents.id
  http_method = aws_api_gateway_method.documents_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "documents_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.documents.id
  http_method = aws_api_gateway_method.documents_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "documents_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.documents.id
  http_method = aws_api_gateway_method.documents_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.documents_options]
}

# --- /documents/upload ---
resource "aws_api_gateway_resource" "documents_upload" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_resource.documents.id
  path_part   = "upload"
}

resource "aws_api_gateway_method" "documents_upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.documents_upload.id
  http_method   = "POST"
  authorization = "NONE"
}

# CORS OPTIONS for /documents/upload
resource "aws_api_gateway_method" "documents_upload_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.documents_upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "documents_upload_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.documents_upload.id
  http_method = aws_api_gateway_method.documents_upload_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "documents_upload_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.documents_upload.id
  http_method = aws_api_gateway_method.documents_upload_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "documents_upload_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.documents_upload.id
  http_method = aws_api_gateway_method.documents_upload_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.documents_upload_options]
}

# --- /chat (Proxy to ECS ALB) ---
resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  parent_id   = aws_api_gateway_rest_api.dochub_api.root_resource_id
  path_part   = "chat"
}

resource "aws_api_gateway_method" "chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "POST"
  authorization = "NONE"
}

# CORS OPTIONS for /chat
resource "aws_api_gateway_method" "chat_options" {
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "chat_options_200" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Tenant-Id'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.api_cors_allowed_origin}'"
  }

  depends_on = [aws_api_gateway_integration.chat_options]
}

# --- Lambda Integrations ---
resource "aws_api_gateway_integration" "auth_login_post" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.auth_login.id
  http_method             = aws_api_gateway_method.auth_login_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "auth_accounts_get" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.auth_accounts.id
  http_method             = aws_api_gateway_method.auth_accounts_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "companies_current_get" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.companies_current.id
  http_method             = aws_api_gateway_method.companies_current_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "companies_register_post" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.companies_register.id
  http_method             = aws_api_gateway_method.companies_register_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "companies_users_post" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.companies_users.id
  http_method             = aws_api_gateway_method.companies_users_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "companies_users_delete" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.companies_users.id
  http_method             = aws_api_gateway_method.companies_users_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "workspaces_get" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.workspaces.id
  http_method             = aws_api_gateway_method.workspaces_get.http_method
  integration_http_method = "POST" # Lambda luôn nhận POST từ API Gateway
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "workspaces_post" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.workspaces.id
  http_method             = aws_api_gateway_method.workspaces_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "workspaces_delete" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.workspaces.id
  http_method             = aws_api_gateway_method.workspaces_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "documents_get" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.documents.id
  http_method             = aws_api_gateway_method.documents_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "documents_delete" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.documents.id
  http_method             = aws_api_gateway_method.documents_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "documents_upload_post" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.documents_upload.id
  http_method             = aws_api_gateway_method.documents_upload_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_handler.invoke_arn
}

resource "aws_api_gateway_integration" "chat_post" {
  rest_api_id             = aws_api_gateway_rest_api.dochub_api.id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.chat_post.http_method
  integration_http_method = "POST"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.ecs_alb.dns_name}/chat"
}

# --- Permission: cho API Gateway gọi Lambda ---
resource "aws_lambda_permission" "api_gw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dochub_api.execution_arn}/*/*"
}

# --- Deploy ---
resource "aws_api_gateway_deployment" "dochub_deploy" {
  rest_api_id = aws_api_gateway_rest_api.dochub_api.id

  depends_on = [
    aws_api_gateway_integration.auth_login_post,
    aws_api_gateway_integration.auth_accounts_get,
    aws_api_gateway_integration.companies_current_get,
    aws_api_gateway_integration.companies_register_post,
    aws_api_gateway_integration.companies_users_post,
    aws_api_gateway_integration.companies_users_delete,
    aws_api_gateway_integration.workspaces_get,
    aws_api_gateway_integration.workspaces_post,
    aws_api_gateway_integration.workspaces_delete,
    aws_api_gateway_integration.documents_get,
    aws_api_gateway_integration.documents_delete,
    aws_api_gateway_integration.documents_upload_post,
    aws_api_gateway_integration.chat_post,
    aws_api_gateway_integration_response.auth_login_options,
    aws_api_gateway_integration_response.auth_accounts_options,
    aws_api_gateway_integration_response.companies_current_options,
    aws_api_gateway_integration_response.companies_register_options,
    aws_api_gateway_integration_response.companies_users_options,
    aws_api_gateway_integration_response.workspaces_options,
    aws_api_gateway_integration_response.documents_options,
    aws_api_gateway_integration_response.documents_upload_options,
    aws_api_gateway_integration_response.chat_options,
  ]

  # Force re-deploy on changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.workspaces,
      aws_api_gateway_resource.auth_login,
      aws_api_gateway_resource.auth_accounts,
      aws_api_gateway_resource.companies_register,
      aws_api_gateway_resource.companies_current,
      aws_api_gateway_resource.companies_users,
      aws_api_gateway_resource.documents,
      aws_api_gateway_resource.documents_upload,
      aws_api_gateway_resource.chat,
      aws_api_gateway_method.auth_login_post,
      aws_api_gateway_method.auth_accounts_get,
      aws_api_gateway_method.companies_register_post,
      aws_api_gateway_method.companies_current_get,
      aws_api_gateway_method.companies_users_post,
      aws_api_gateway_method.companies_users_delete,
      aws_api_gateway_method.workspaces_get,
      aws_api_gateway_method.workspaces_post,
      aws_api_gateway_method.workspaces_delete,
      aws_api_gateway_method.documents_get,
      aws_api_gateway_method.documents_delete,
      aws_api_gateway_method.documents_upload_post,
      aws_api_gateway_method.chat_post,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.dochub_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.dochub_api.id
  stage_name    = "prod"
  tags          = { Name = "${local.resource_base_name}-api-prod-stage" }
}

# --- Output: URL cho Frontend ---
output "api_gateway_url" {
  description = "Base URL cho Frontend (điền vào VITE_API_URL)"
  value       = aws_api_gateway_stage.prod.invoke_url
}
