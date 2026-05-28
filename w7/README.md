# DocHub AI

DocHub AI is the W7 ProductivityTech project: a multi-tenant document hub where users upload PDF/DOCX files and ask AI questions grounded in their workspace documents.

## Local Frontend

```bash
cd w7/frontend
npm install
copy .env.example .env
npm run dev
```

Set `VITE_API_URL` in `.env` to the API Gateway stage URL after Terraform deploy.

## Local AI Backend

```bash
cd w7/ai-backend
python -m pip install -r requirements.txt
copy .env.example .env
python -m uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

The backend requires AWS credentials with Bedrock access and the environment variables listed in `.env.example`.

## Validation

Frontend:

```bash
cd w7/frontend
npm run lint
npm run build
```

Python syntax check:

```bash
python -m compileall w7/ai-backend/src w7/lambda
```

## Submission Artifacts

W7 graded artifacts live in the repository `docs/` directory:

- `docs/W7_evidence.md` - evidence pack with architecture, security, monitoring, cost, decisions, and teardown plan.
- `docs/architecture.md` - final deploy architecture diagram and capability mapping.
- `docs/aws_console_checklist.md` - AWS Console items and screenshots that must be captured manually.
- `docs/demo_script.md` - 3-minute demo recording script.
- `docs/slides_outline.md` - 12-18 slide outline for the final presentation.
- `docs/submission_checklist.md` - final live demo and QnA checklist.
- `docs/teardown_confirmation.md` - post-demo teardown confirmation template.
- `docs/evidence/` - place Cost Explorer, CloudWatch, IAM, S3, and teardown screenshots here.

Before the final submission, replace every `ACTION REQUIRED` marker in `docs/W7_evidence.md` and `docs/teardown_confirmation.md` with live AWS/account evidence.

## Deployment Notes

Terraform lives in `w7/terraform`. It defines the S3 buckets, CloudFront frontend hosting, API Gateway, Lambda functions, ECS AI backend, DynamoDB tables, Bedrock Knowledge Base, and networking.

The GitHub Actions deployment workflow is `.github/workflows/deploy.yml`. It expects a repository secret named `AWS_ROLE_TO_ASSUME` containing the ARN of an AWS IAM role trusted by GitHub OIDC for this repository.

Minimum AWS Console setup for GitHub Actions:

1. Create an IAM OIDC provider for `https://token.actions.githubusercontent.com` if the account does not already have one.
2. Create an IAM role trusted by that provider and scoped to this GitHub repository/branch.
3. Attach deployment permissions for Terraform-managed W7 resources, ECR image push, S3 frontend upload, and CloudFront invalidation.
4. Add the role ARN to the GitHub repository secret `AWS_ROLE_TO_ASSUME`.

Security hardening included in Terraform:

- Document and frontend S3 buckets block public access, enforce bucket-owner object ownership, enable SSE-S3 encryption, enable versioning, and deny non-TLS access.
- The document bucket has lifecycle rules for incomplete multipart uploads and old noncurrent versions.
- DynamoDB tables enable point-in-time recovery.
- Lambda and ECS now use separate execution/task roles instead of a shared trust policy.
- Browser CORS defaults to the deployed CloudFront frontend URL. For local testing, pass `additional_s3_cors_origins` and/or `allowed_cors_origin` through Terraform variables.
- OpenSearch Serverless index admin principals are configurable with `opensearch_index_admin_arns`; the deploy workflow passes the GitHub OIDC role ARN automatically.

Tenant isolation implemented in code:

- The frontend attaches `X-Tenant-Id` to API requests from the selected demo tenant.
- Lambda derives workspace ownership from `X-Tenant-Id` and DynamoDB instead of trusting the request body.
- Workspace listing, document listing, and upload initialization only operate on workspaces owned by the tenant.
- The AI backend validates `X-Tenant-Id` against `DocHub_Workspaces` before running Bedrock retrieval/generation.
- Bedrock metadata now includes both `workspace_id` and `tenant_name`; retrieval still filters by `workspace_id`.

Document ingestion flow:

- Upload initialization creates documents as `PENDING`.
- S3 upload completion moves documents to `UPLOADED`, then starts a Bedrock Knowledge Base ingestion job.
- While Bedrock is syncing, documents stay `INDEXING`; EventBridge ingestion events move them to `READY` or `ERROR`.
- The frontend polls processing documents and only enables chat after at least one document in the workspace is `READY`.

Observability included in Terraform:

- CloudWatch dashboard `g5-dochub-ai-observability` tracks Lambda invocations/errors, API Gateway 4xx/5xx/latency, custom document upload counts, chat request counts, chat errors, and AI chat latency.
- The event handler publishes custom metric `DocHub/DocumentsUploaded` after S3 upload completion.
- The AI backend publishes `DocHub/ChatRequests`, `DocHub/ChatErrors`, and `DocHub/ChatLatencyMs` around Bedrock RAG calls.
- CloudWatch alarms `dochub-documents-uploaded-spike` and `dochub-api-lambda-errors` are configured with missing data treated as not breaching so they settle into OK/ALARM instead of staying in insufficient data.
- A saved Logs Insights query named `dochub-application-errors` searches Lambda and ECS logs for recent errors, exceptions, failures, and tracebacks.

The demo login is still intentionally simple for W7. For a production auth boundary, replace the demo tenant header with Cognito/JWT claims and keep the same server-side workspace ownership checks.

Before deploying paid AWS resources, confirm:

- AWS Budget alert at 80 USD is configured and SNS email is confirmed.
- Bedrock model access is enabled in the target region.
- Every resource is tagged with project/team/owner metadata.
- A teardown plan is ready before the demo.

## Teardown

Primary teardown command:

```bash
cd w7/terraform
terraform destroy
```

After destroy, manually verify OpenSearch Serverless, ALB/ECS, S3 buckets, CloudFront, DynamoDB, Bedrock Knowledge Base, CloudWatch resources, and VPC resources are gone. Record final evidence in `docs/teardown_confirmation.md` and save the Cost Explorer screenshot as `docs/teardown_confirmed.png`.
