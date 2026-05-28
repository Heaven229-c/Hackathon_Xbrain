# W7 Teardown Confirmation

Status: ACTION REQUIRED after final demo.

## Teardown Command

```bash
cd w7/terraform
terraform destroy
```

## Confirmation Checklist

Record the actual result after teardown.

| Resource area | Expected status | Evidence |
| --- | --- | --- |
| CloudFront distribution | Deleted or disabled and no longer serving demo traffic | ACTION REQUIRED |
| Frontend S3 bucket | Deleted | ACTION REQUIRED |
| Document S3 bucket | Empty and deleted | ACTION REQUIRED |
| API Gateway REST API | Deleted | ACTION REQUIRED |
| Lambda functions | Deleted | ACTION REQUIRED |
| ECS service and cluster | Deleted | ACTION REQUIRED |
| ALB and target group | Deleted | ACTION REQUIRED |
| ECR repository | Deleted | ACTION REQUIRED |
| DynamoDB tables | Deleted | ACTION REQUIRED |
| Bedrock Knowledge Base and data source | Deleted | ACTION REQUIRED |
| OpenSearch Serverless collection and policies | Deleted | ACTION REQUIRED |
| CloudWatch dashboard and alarms | Deleted | ACTION REQUIRED |
| VPC, subnets, route tables, security groups | Deleted | ACTION REQUIRED |
| GitHub OIDC role | Keep only if reused; otherwise delete | ACTION REQUIRED |

## Cost Explorer Verification

- Final verification date: ACTION REQUIRED
- AWS account ID: ACTION REQUIRED
- Cost Explorer screenshot: `docs/teardown_confirmed.png`
- Remaining W7 resources found: ACTION REQUIRED

## Notes

OpenSearch Serverless and ALB are the most important resources to verify manually because they can keep billing after the demo if Terraform destroy is incomplete.
