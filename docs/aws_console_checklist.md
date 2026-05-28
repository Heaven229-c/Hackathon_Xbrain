# AWS Console Checklist

Use this checklist for items that cannot be completed from code alone.

## Before Deploying Paid Resources

- [ ] Root account MFA is enabled.
- [ ] AWS Budget alert is created at 80 USD.
- [ ] Budget SNS/email subscription is confirmed.
- [ ] Cost Anomaly Detection monitor is enabled.
- [ ] Bedrock model access is granted in `us-west-2`.
- [ ] GitHub OIDC deploy role exists and its ARN is saved as repository secret `AWS_ROLE_TO_ASSUME`.

## After Terraform Deploy

- [ ] CloudFront distribution URL loads the frontend.
- [ ] API Gateway `prod` invoke URL is copied into evidence.
- [ ] Bedrock Knowledge Base is active.
- [ ] OpenSearch Serverless collection is active.
- [ ] ECS service has one healthy running task.
- [ ] ALB target group shows healthy target.
- [ ] Lambda functions have recent successful invocations.
- [ ] Document S3 bucket has Block Public Access enabled.
- [ ] DynamoDB tables have PITR enabled.
- [ ] CloudWatch dashboard `g5-dochub-ai-observability` is visible.
- [ ] CloudWatch alarms are `OK` or `ALARM`, not `INSUFFICIENT_DATA`.

## Screenshots To Save

Save these under `docs/evidence/`.

- [ ] `cost_day1.png`
- [ ] `cost_day2.png`
- [ ] `cost_demo_day.png`
- [ ] `cloudwatch_dashboard.png`
- [ ] `cloudwatch_alarms.png`
- [ ] `logs_insights_query.png`
- [ ] `iam_lambda_policy.png`
- [ ] `s3_security.png`
- [ ] `dynamodb_pitr.png`
- [ ] `tenant_isolation_demo.png`
- [ ] `live_frontend.png`
- [ ] `teardown_confirmed.png` after final teardown
