# DocHub AI Demo Script

Target length: 3 minutes.

## Setup Before Recording

- Confirm `VITE_API_URL` points to the deployed API Gateway `prod` stage.
- Open the CloudFront frontend URL in a clean browser session.
- Prepare one small PDF or DOCX with obvious facts for the trainer question.
- Open CloudWatch dashboard `g5-dochub-ai-observability` in another tab.
- Open `docs/W7_evidence.md` in the repo.

## Script

1. Intro, 15 seconds

   "This is DocHub AI, a multi-tenant ProductivityTech document hub. The goal is to let a team upload internal documents and ask AI questions without leaking data across tenants."

2. Login and workspace, 25 seconds

   "I select a demo tenant. This is intentionally lightweight for W7, but the backend still enforces tenant ownership on every workspace, document, and chat request."

   Action: log in, create or open a workspace.

3. Upload and ingestion status, 45 seconds

   "I upload a PDF or DOCX. The app creates a pending document, uploads directly to S3 with a presigned POST, then waits for the ingestion pipeline. It does not mark the file ready until Bedrock ingestion completes."

   Action: upload the prepared file, show status moving through `UPLOADED` or `INDEXING`. If a previous file is already `READY`, point to that ready file.

4. Ask AI question, 45 seconds

   "Now that the document is ready, chat is enabled. The AI backend checks that the workspace belongs to this tenant, then calls Bedrock RetrieveAndGenerate with a workspace metadata filter."

   Action: ask a question that has an answer in the uploaded document. Show answer and source badge if present.

5. Observability, 30 seconds

   "For the optional capability, we implemented Full Observability. The dashboard shows Lambda health, API Gateway errors and latency, custom upload/chat metrics, and recent application errors."

   Action: switch to CloudWatch dashboard. Show `DocumentsUploaded`, `ChatRequests`, and alarm state.

6. Architecture close, 20 seconds

   "The public entry is CloudFront and S3. API Gateway routes metadata APIs to Lambda and chat to ECS through ALB. S3 stores documents, DynamoDB stores state, and Bedrock Knowledge Base handles RAG. Terraform can deploy and tear down the stack."

7. Cost and teardown close, 20 seconds

   "The main fixed cost is OpenSearch Serverless for the vector store, so teardown is part of the submission. The evidence pack includes cost screenshots, monitoring evidence, trade-offs, and teardown confirmation."

## Fallback Plan

If live ingestion is slow during recording, use a document that was uploaded earlier and is already `READY`. State clearly that the visible status badge proves ingestion completed before chat was enabled.
