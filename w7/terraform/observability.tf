# -----------------------------------------------------------------------------
# 10. CloudWatch observability
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "documents_uploaded_spike" {
  alarm_name          = "${local.resource_base_name}-documents-uploaded-spike"
  alarm_description   = "Alerts if document uploads exceed the expected hackathon demo volume."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "DocumentsUploaded"
  namespace           = local.metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 20
  treat_missing_data  = "notBreaching"

  dimensions = {
    Service = "EventHandler"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_lambda_errors" {
  alarm_name          = "${local.resource_base_name}-api-lambda-errors"
  alarm_description   = "Alerts when the public API Lambda records any errors in a 5-minute window."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.api_handler.function_name
  }
}

resource "aws_cloudwatch_query_definition" "application_errors" {
  name = "${local.resource_base_name}-application-errors"

  log_group_names = [
    "/aws/lambda/${aws_lambda_function.api_handler.function_name}",
    "/aws/lambda/${aws_lambda_function.event_handler.function_name}",
    aws_cloudwatch_log_group.ecs_logs.name
  ]

  query_string = <<-EOT
    fields @timestamp, @log, @message
    | filter @message like /(?i)(error|exception|failed|traceback)/
    | sort @timestamp desc
    | limit 50
  EOT
}

resource "aws_cloudwatch_dashboard" "dochub" {
  dashboard_name = "${local.resource_base_name}-ai-observability"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "## ${local.resource_base_name} AI Observability\nTracks Lambda/API health, document ingestion, and AI chat latency for W7 evidence."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Invocations and Errors"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.api_handler.function_name, { label = "API invocations" }],
            [".", "Errors", ".", ".", { label = "API errors" }],
            [".", "Invocations", ".", aws_lambda_function.event_handler.function_name, { label = "Event handler invocations" }],
            [".", "Errors", ".", ".", { label = "Event handler errors" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway Errors and Latency"
          region = var.aws_region
          period = 300
          view   = "timeSeries"
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.dochub_api.name, "Stage", aws_api_gateway_stage.prod.stage_name, { stat = "Sum", label = "4XX errors" }],
            [".", "5XXError", ".", ".", ".", ".", { stat = "Sum", label = "5XX errors" }],
            [".", "Latency", ".", ".", ".", ".", { stat = "Average", label = "Average latency" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Custom Application Metrics"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          view   = "timeSeries"
          metrics = [
            [local.metric_namespace, "DocumentsUploaded", "Service", "EventHandler", { label = "Documents uploaded" }],
            [".", "ChatRequests", ".", "AIBackend", { label = "Chat requests" }],
            [".", "ChatErrors", ".", ".", { label = "Chat errors" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "AI Chat Latency"
          region = var.aws_region
          period = 300
          stat   = "Average"
          view   = "timeSeries"
          metrics = [
            [local.metric_namespace, "ChatLatencyMs", "Service", "AIBackend", { label = "Average chat latency" }]
          ]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 14
        width  = 24
        height = 6
        properties = {
          title   = "Recent Application Errors"
          region  = var.aws_region
          view    = "table"
          stacked = false
          query   = "SOURCE '/aws/lambda/${aws_lambda_function.api_handler.function_name}' | fields @timestamp, @log, @message | filter @message like /(?i)(error|exception|failed|traceback)/ | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard for W7 observability evidence"
  value       = aws_cloudwatch_dashboard.dochub.dashboard_name
}

output "cloudwatch_dashboard_url" {
  description = "Direct AWS Console URL for the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.dochub.dashboard_name}"
}

output "cloudwatch_alarm_names" {
  description = "CloudWatch alarms created for observability evidence"
  value = [
    aws_cloudwatch_metric_alarm.documents_uploaded_spike.alarm_name,
    aws_cloudwatch_metric_alarm.api_lambda_errors.alarm_name
  ]
}

output "cloudwatch_logs_query_name" {
  description = "Saved CloudWatch Logs Insights query for application errors"
  value       = aws_cloudwatch_query_definition.application_errors.name
}
