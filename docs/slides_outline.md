# W7 Slides Outline

Target: 12-18 slides. Architecture walkthrough should take the most time.

## Slide Plan

1. Title
   - DocHub AI
   - ProductivityTech
   - Group 5 and member names

2. Problem
   - Teams have documents but slow answers.
   - Risk: wrong document or wrong tenant data.

3. Product Vision
   - Multi-tenant document workspaces.
   - Upload PDF/DOCX.
   - Ask grounded AI questions.

4. Live Demo Flow
   - Login as demo tenant.
   - Create/open workspace.
   - Upload document.
   - Wait for `READY`.
   - Ask AI question.

5. Final Architecture Diagram
   - Use diagram from `docs/architecture.md`.

6. Mandatory Capability Mapping
   - CloudFront/S3, API Gateway, Lambda/ECS, Bedrock, DynamoDB, S3, VPC, IAM.

7. Request Path: Upload
   - API Lambda creates `PENDING`.
   - Browser uploads to S3.
   - Event Lambda starts Bedrock ingestion.

8. Request Path: Chat
   - API Gateway to ALB/ECS.
   - Workspace ownership check.
   - Bedrock RetrieveAndGenerate with metadata filter.

9. Tenant Isolation
   - `X-Tenant-Id` demo context.
   - Server-side ownership checks.
   - Metadata fields: `workspace_id`, `tenant_name`.

10. AI Design
    - Bedrock Knowledge Base.
    - Titan embeddings / vector store.
    - Claude Haiku model choice.

11. Security And IAM
    - Least-privilege roles.
    - S3 public access blocked.
    - TLS-only bucket policy.
    - DynamoDB PITR.

12. Observability Optional Capability
    - Dashboard.
    - Custom metrics.
    - Alarms.
    - Logs Insights query.

13. CI/CD And IaC
    - GitHub Actions OIDC.
    - Terraform.
    - ECR Docker image.
    - S3 sync + CloudFront invalidation.

14. Cost Discipline
    - Total spend.
    - Top 3 cost drivers.
    - Why OpenSearch Serverless is teardown priority.

15. Key Trade-Offs
    - Shared KB with metadata filtering.
    - Demo tenant header vs Cognito.
    - CloudFront/S3 vs frontend server.

16. Lessons Learned
    - Ingestion state matters.
    - Tenant isolation is the core risk.
    - What would change for production.

17. Teardown Plan
    - Terraform destroy.
    - Verify OpenSearch, ALB/ECS, S3, CloudFront.
    - Cost Explorer screenshot.

18. QnA Backup
    - Service decision table.
    - Links to evidence pack and repo.
