# W7 AWS Deployment Runbook - DocHub AI

Runbook nay dung de deploy project `w7` len AWS account moi, region mac dinh `us-west-2`.

Trang thai code hien tai:

- Model chat mac dinh: `us.anthropic.claude-haiku-4-5-20251001-v1:0`.
- Embedding KB mac dinh: `amazon.titan-embed-text-v2:0`.
- Account demo duoc seed vao DynamoDB table `users`, khong hard-code trong frontend.
- Company demo duoc seed vao DynamoDB table `companies`.
- Co the dang ky company moi tren Login page; company admin dau tien duoc tao tu dong.
- Moi company admin co the tao va xoa user trong company cua minh.
- Knowledge base id duoc namespace theo company de tranh trung ten giua cac company.
- Upload tai lieu se tao S3 object + metadata sidecar, Lambda se auto start Bedrock ingestion job.
- Chat chi mo khi co it nhat 1 document status `READY`.

## 1. Chuan bi local

Can co:

- AWS CLI
- Docker Desktop
- Node.js 24 hoac tuong duong
- Python 3.11+
- Terraform tai `E:\Terraform\terraform.exe`

Sau khi clone source code, mo PowerShell tai thu muc root cua repo, tuc thu muc co chua `w7` va `xbrain-learners`.
Tat ca lenh `cd .\...` trong runbook nay deu gia dinh ban dang dung o repo root. Neu dang o thu muc khac, hay `cd` vao repo root truoc.

Kiem tra:

```powershell
aws --version
docker version
node --version
npm --version
python --version
E:\Terraform\terraform.exe version
```

## 2. Chuan bi AWS account

Tren AWS Console:

1. Chon region `Oregon / us-west-2`.
2. Bat MFA cho root account.
3. Tao Budget canh bao `$80`.
4. Bat Cost Anomaly Detection neu account cho phep.
5. Tao IAM user/role dung de deploy.
6. Trong hackathon co the gan tam `AdministratorAccess` cho deploy principal.
7. Tao access key neu dung AWS CLI local.

Khong dua AWS access key vao source code, `.env`, tai lieu commit, hoac GitHub.

## 3. Bat Bedrock model access

Trong Amazon Bedrock tai `us-west-2`, vao `Model access` va enable:

- Chat model: `Claude Haiku 4.5` hoac model khac ban chon.
- Embedding model: `Titan Text Embeddings v2` hoac embedding model khac.

Voi Claude Haiku 4.5, project dang dung inference profile id:

```text
us.anthropic.claude-haiku-4-5-20251001-v1:0
```

Khong nen dien model id goc `anthropic.claude-haiku-4-5-20251001-v1:0` neu AWS yeu cau inference profile. Neu muon dung global profile, co the thu:

```text
global.anthropic.claude-haiku-4-5-20251001-v1:0
```

## 4. Cau hinh AWS CLI profile

```powershell
aws configure --profile xbrain
```

Nhap:

```text
AWS Access Key ID: <access-key>
AWS Secret Access Key: <secret-key>
Default region name: us-west-2
Default output format: json
```

Set profile cho PowerShell hien tai:

```powershell
$env:AWS_PROFILE="xbrain"
$env:AWS_REGION="us-west-2"
aws sts get-caller-identity
```

Lay ARN cua principal dang deploy:

```powershell
aws sts get-caller-identity --query Arn --output text
```

Neu ARN co dang `arn:aws:sts::...:assumed-role/...`, hay dien IAM Role ARN that vao Terraform:

```text
arn:aws:iam::<account-id>:role/<role-name>
```

## 5. Tao `terraform.tfvars`

```powershell
cd .\w7\terraform
Copy-Item terraform.tfvars.example terraform.tfvars
```

Mo `w7/terraform/terraform.tfvars` va dien:

```hcl
aws_region = "us-west-2"

resource_name_prefix = "g5"

bedrock_model_id = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
demo_auth_secret = "<REPLACE_WITH_A_PRIVATE_DEMO_AUTH_SECRET>"
demo_user_password = "<REPLACE_WITH_A_DEMO_USER_PASSWORD>"

bedrock_embedding_model_id = "amazon.titan-embed-text-v2:0"
embedding_vector_dimension = 1024
min_retrieval_score = 0

opensearch_index_admin_arns = [
  "<YOUR_IAM_USER_OR_ROLE_ARN>"
]

ai_backend_image_tag = "latest"

additional_s3_cors_origins = [
  "http://localhost:5173"
]
```

Giai thich nhanh:

- `resource_name_prefix`: prefix tranh trung resource voi thanh vien khac; voi cau hinh hien tai la `g5`, nen resource AWS se co dang `g5-dochub-*`.
- `bedrock_model_id`: model chat cho AI backend.
- `demo_auth_secret`: secret ky token demo, phai thay moi khi deploy.
- `demo_user_password`: password ban dau cho 4 demo users duoc seed vao DynamoDB.
- `bedrock_embedding_model_id`: embedding model cho Bedrock KB.
- `embedding_vector_dimension`: dimension dung voi embedding model.
- `min_retrieval_score`: de `0` cho demo an toan; tang sau khi do retrieval quality.
- `opensearch_index_admin_arns`: user/role duoc phep tao OpenSearch Serverless vector index.

Khong commit `terraform.tfvars`.

## 6. Cai dependency cho Terraform helper

Terraform se chay Python script de tao OpenSearch Serverless vector index:

```powershell
python -m pip install boto3 opensearch-py requests-aws4auth
```

## 7. Terraform init, fmt, validate

```powershell
cd .\w7\terraform

E:\Terraform\terraform.exe init
E:\Terraform\terraform.exe fmt -recursive
E:\Terraform\terraform.exe validate
```

## 8. Tao ECR truoc

Backend ECS can Docker image truoc khi service chay.

```powershell
cd .\w7\terraform
E:\Terraform\terraform.exe apply -var-file="terraform.tfvars" -target=aws_ecr_repository.ai_backend
```

Lay ECR URL:

```powershell
$ECR = E:\Terraform\terraform.exe output -raw ai_backend_ecr_repository_url
$ECR_REGISTRY = $ECR.Split('/')[0]
$ECR
$ECR_REGISTRY
```

## 9. Build va push AI backend image

```powershell
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REGISTRY

cd .\w7\ai-backend
docker build -t g5-dochub-ai-backend:latest .
docker tag g5-dochub-ai-backend:latest "${ECR}:latest"
docker push "${ECR}:latest"
```

## 10. Deploy toan bo ha tang

```powershell
cd .\w7\terraform

E:\Terraform\terraform.exe plan -var-file="terraform.tfvars"
E:\Terraform\terraform.exe apply -var-file="terraform.tfvars"
```

Terraform se tao:

- DynamoDB: workspaces, documents, companies, users
- 4 demo users: Company A/B admin/member
- S3 document bucket va frontend bucket
- API Gateway REST API
- Lambda API handler va event handler
- ECS Fargate AI backend
- ALB cho ECS
- VPC, subnets, route tables, security groups, endpoints/NAT theo Terraform
- OpenSearch Serverless collection va index
- Bedrock Knowledge Base va Data Source
- EventBridge rule cho Bedrock ingestion status
- CloudWatch dashboard, alarms, log query
- CloudFront HTTPS frontend

## 11. Lay output sau deploy

```powershell
cd .\w7\terraform

$API_URL = E:\Terraform\terraform.exe output -raw api_gateway_url
$FRONTEND_BUCKET = E:\Terraform\terraform.exe output -raw frontend_bucket_name
$CLOUDFRONT_ID = E:\Terraform\terraform.exe output -raw cloudfront_distribution_id
$FRONTEND_URL = E:\Terraform\terraform.exe output -raw frontend_url

$API_URL
$FRONTEND_BUCKET
$CLOUDFRONT_ID
$FRONTEND_URL
```

## 12. Build va upload frontend

```powershell
cd .\w7\frontend

"VITE_API_URL=$API_URL" | Set-Content .env -Encoding ASCII

npm install
npm run build
```

Upload:

```powershell
aws s3 sync dist "s3://$FRONTEND_BUCKET" --delete --region us-west-2
aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
```

Mo frontend:

```powershell
$FRONTEND_URL
```

## Không cần triển khai phần dưới

## 13. Smoke test API dung auth moi

Lay danh sach demo accounts:

```powershell
Invoke-RestMethod -Method Get -Uri "$API_URL/auth/accounts"
```

Login bang admin Company A:

```powershell
$Login = Invoke-RestMethod `
  -Method Post `
  -Uri "$API_URL/auth/login" `
  -ContentType "application/json" `
  -Body '{"email":"admin@companya.test","password":"<DEMO_USER_PASSWORD>"}'

$Token = $Login.token
$TenantId = $Login.user.tenant_id
$Headers = @{
  Authorization = "Bearer $Token"
  "X-Tenant-Id" = $TenantId
}
```

Kiem tra company users:

```powershell
Invoke-RestMethod `
  -Method Get `
  -Uri "$API_URL/companies/current" `
  -Headers $Headers
```

Tao user moi trong company hien tai:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$API_URL/companies/users" `
  -Headers $Headers `
  -ContentType "application/json" `
  -Body '{"email":"reviewer@companya.test","password":"123456","role":"member"}'
```

Xoa user trong company hien tai:

```powershell
Invoke-RestMethod `
  -Method Delete `
  -Uri "$API_URL/companies/users?email=reviewer@companya.test" `
  -Headers $Headers
```

Dang ky company moi co the lam tren Login page, hoac test bang API:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$API_URL/companies/register" `
  -ContentType "application/json" `
  -Body '{"company_name":"Company C","admin_email":"admin@companyc.test","admin_password":"123456"}'
```

Tao knowledge base:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri "$API_URL/workspaces" `
  -Headers $Headers `
  -ContentType "application/json" `
  -Body '{"workspace_id":"contracts","workspace_name":"Contracts"}'
```

List knowledge bases:

```powershell
Invoke-RestMethod `
  -Method Get `
  -Uri "$API_URL/workspaces" `
  -Headers $Headers
```

Ket qua `workspace_id` se co namespace theo company, vi du:

```text
company-a-contracts
```

## 14. Chay local frontend neu can

```powershell
cd .\w7\frontend
"VITE_API_URL=$API_URL" | Set-Content .env -Encoding ASCII
npm install
npm run dev
```

Mo:

```text
http://localhost:5173
```

Trong `terraform.tfvars`, can co:

```hcl
additional_s3_cors_origins = [
  "http://localhost:5173"
]
```

## 15. Chay AI backend local neu can

Production ECS khong can `.env`; Terraform inject env vao ECS task.

Neu muon chay local, tao `w7/ai-backend/.env`:

```env
AWS_REGION=us-west-2
BEDROCK_KB_ID=<KB_ID>
BEDROCK_DS_ID=<DATA_SOURCE_ID>
BEDROCK_MODEL_ID=us.anthropic.claude-haiku-4-5-20251001-v1:0
MIN_RETRIEVAL_SCORE=0
DYNAMODB_TABLE=g5-dochub-documents
WORKSPACE_TABLE=g5-dochub-workspaces
DEMO_AUTH_SECRET=<same-as-terraform>
METRIC_NAMESPACE=g5-DocHub
ALLOWED_ORIGINS=http://localhost:5173
```

Lay KB ID va Data Source ID:

```powershell
$KB_ID = aws bedrock-agent list-knowledge-bases `
  --region us-west-2 `
  --query "knowledgeBaseSummaries[?name=='g5-dochub-ai-kb'].knowledgeBaseId | [0]" `
  --output text

$DS_ID = aws bedrock-agent list-data-sources `
  --region us-west-2 `
  --knowledge-base-id $KB_ID `
  --query "dataSourceSummaries[?name=='g5-dochub-ai-s3-datasource'].dataSourceId | [0]" `
  --output text
```

Chay:

```powershell
cd .\w7\ai-backend
python -m pip install -r requirements.txt
python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

## 16. Cach kiem tra upload, sync, chat

Tren frontend:

1. Login bang `admin@companya.test` va password trong `demo_user_password`.
2. Tao Knowledge Base.
3. Upload PDF/DOCX duoi 10 MB.
4. Cho status chuyen:
   - `PENDING`: da tao document record.
   - `UPLOADED`: S3 upload xong.
   - `INDEXING`: Bedrock ingestion job dang chay.
   - `READY`: chat duoc mo.
   - `ERROR`: xem error message tren UI hoac CloudWatch logs.
5. Dat cau hoi trong chat.

Neu chat bi khoa voi thong bao `Upload a document and wait until it is ready`, kiem tra:

- Lambda event handler co log start ingestion job khong.
- Bedrock Data Source co ingestion job moi khong.
- Document status trong DynamoDB co `READY` khong.
- S3 object co file `.metadata.json` di kem khong.
- Model embedding da enable trong Bedrock chua.

## 17. Prompt/model hien tai dap ung yeu cau nao

Prompt trong `w7/ai-backend/src/rag_pipeline.py` da ep:

- Chi tra loi tu excerpts.
- Moi claim quan trong phai cite filename/source.
- Khong dung external knowledge.
- Khong nghe instruction nam trong document.
- Uu tien `is_latest=true`, `document_version`, `uploaded_at`.
- Neu nhieu tai lieu lien quan va cau hoi mo ho, phai noi ro ambiguity.
- Neu source conflict, phai neu file conflict, khong gop thanh mot cau tra loi.
- Neu evidence yeu hoac retrieval score thap, phai ha confidence.
- Neu cau hoi dang loc danh sach nhu "Which agreements have termination notice under 30 days?", phai tra ve numbered list chi gom tai lieu dat dieu kien.
- Khong tu liet ke "Other agreements" hoac tai lieu khong dat dieu kien neu user khong hoi.
- Backend retrieve filter o Bedrock bang `workspace_id`, `tenant_name`, `is_latest=true`.
- Neu query nhac ro document name, backend match filename latest trong DynamoDB va filter them `document_id` ngay o retrieval stage.
- Backend dung dynamic top-k: document-specific query toi da 6 chunks, filtered-list query toi da 20 chunks, query thuong toi da 8 chunks.
- Backend hau kiem metadata `workspace_id`/`tenant_name`/`document_id`/`is_latest` truoc khi dua context vao model.

Day la phan dap ung AI core cho domain ProductivityTech DocHub. Tuy nhien de dat diem cao theo yeu cau W7, van can tu do va ghi evidence:

- Wrong-doc rate tren bo query mau.
- Retrieval quality voi 10-20 cau hoi.
- Ly do chon model Haiku 4.5 so voi Nova/Haiku 3.5/Sonnet.
- Cost-per-feature cua moi chat/upload.

Dung file `xbrain-learners/W7_TOPIC3_WRONG_DOC_EVAL.md` de dien 20 query va tinh wrong-doc rate cho Evidence Pack.

## 18. Cac file can dien

Bat buoc:

- `w7/terraform/terraform.tfvars`
- `w7/frontend/.env`

Chi can khi chay backend local:

- `w7/ai-backend/.env`

Khong can tu dien `BEDROCK_KB_ID`, `BEDROCK_DS_ID`, `DYNAMODB_TABLE`, `WORKSPACE_TABLE` cho ECS production. Terraform tu inject.

## 19. Teardown sau demo

Xoa ha tang:

```powershell
cd .\w7\terraform
E:\Terraform\terraform.exe destroy -var-file="terraform.tfvars"
```

Sau khi destroy, kiem tra Console:

- ECS cluster da mat.
- ECR repo da mat.
- OpenSearch Serverless collection da mat.
- S3 buckets prefix `g5-dochub-` da mat.
- DynamoDB tables `g5-dochub-*` da mat.
- CloudWatch dashboard da mat.
- API Gateway da mat.
- CloudFront distribution da mat.

Neu destroy loi do bucket/image/object con ton tai, xoa thu cong resource bi chan roi chay lai destroy.

## 20. Checklist nhanh

- [ ] AWS CLI profile `xbrain` hoat dong.
- [ ] Region la `us-west-2`.
- [ ] Bedrock chat model da enable.
- [ ] Bedrock embedding model da enable.
- [ ] `terraform.tfvars` co `resource_name_prefix`.
- [ ] `bedrock_model_id` dung inference profile neu dung Claude Haiku 4.5.
- [ ] `demo_auth_secret` da thay.
- [ ] `demo_user_password` da thay.
- [ ] `opensearch_index_admin_arns` la ARN that cua user/role deploy.
- [ ] ECR da tao.
- [ ] Docker image da push.
- [ ] `terraform apply` chay xong.
- [ ] Frontend `.env` co `VITE_API_URL`.
- [ ] Frontend da build va sync len S3.
- [ ] CloudFront invalidation da chay.
- [ ] Smoke test `/auth/login`, `/companies/current`, `/workspaces` thanh cong.
- [ ] Upload file chuyen den `READY`.
- [ ] Chat tra loi co citation va confidence.
