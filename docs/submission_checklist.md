# W7 Submission Checklist

## Required Before Demo Slot

- [ ] Live CloudFront URL works from a different network.
- [ ] API Gateway URL responds through the deployed frontend.
- [ ] Demo tenant can create/open a workspace.
- [ ] PDF/DOCX upload succeeds.
- [ ] Document reaches `READY`.
- [ ] Chat returns a Bedrock-grounded answer.
- [ ] CloudWatch dashboard has fresh data.
- [ ] CloudWatch alarms are `OK` or `ALARM`, not `INSUFFICIENT_DATA`.
- [ ] `docs/W7_evidence.md` has live URL, repo URL, cost total, and screenshots.
- [ ] `docs/evidence/cost_day1.png` is added.
- [ ] `docs/evidence/cost_day2.png` is added.
- [ ] `docs/evidence/cost_demo_day.png` is added.
- [ ] `docs/evidence/cloudwatch_dashboard.png` is added.
- [ ] Demo video is committed as `docs/demo.mp4` or linked in README.
- [ ] Slides are committed as `docs/slides.pdf`.

## QnA Points To Rehearse

- Why CloudFront + S3 for the public frontend instead of running a frontend server.
- Why Lambda for metadata APIs and ECS for the AI backend.
- Why DynamoDB fits workspace/document metadata.
- Why one Bedrock Knowledge Base with metadata filtering is cheaper than one KB per tenant.
- How cross-tenant leakage is prevented.
- What happens between upload and `READY`.
- Which CloudWatch custom metrics prove observability.
- What the top cost driver is and why teardown is mandatory.
- What would change for production auth: replace demo tenant header with Cognito/JWT claims.

## After Demo

- [ ] Run `terraform destroy`.
- [ ] Verify OpenSearch Serverless is gone.
- [ ] Verify ALB/ECS are gone.
- [ ] Verify S3 buckets are empty/deleted.
- [ ] Verify Cost Explorer the next morning.
- [ ] Commit `docs/teardown_confirmed.png`.
- [ ] Update `docs/teardown_confirmation.md`.
