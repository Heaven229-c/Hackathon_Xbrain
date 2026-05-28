# W7 Topic 3 Wrong-Document and Freshness Evaluation

Muc dich: day la bang dien evidence cho yeu cau Topic 3:

- Do wrong-doc rate tren 20 cau hoi mau.
- Chung minh AI khong lay nham tenant/workspace.
- Chung minh latest document/version duoc uu tien.

## Cach chay

1. Upload toi thieu 20 PDF/DOCX vao mot Knowledge Base cua Company A.
2. Upload 2-3 tai lieu tuong tu vao Company B de test tenant isolation.
3. Doi tat ca document trong Company A chuyen sang `READY`.
4. Hoi tung query ben duoi trong UI.
5. Kiem tra answer cite dung filename va dung dieu khoan.
6. Dien `PASS` neu source dung, `FAIL` neu cite sai document hoac sai version.

Cong thuc:

```text
wrong_doc_rate = failed_queries / 20 * 100
```

## Evaluation Table

| # | Query | Expected source(s) | Expected fact | Actual cited source(s) | PASS/FAIL | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Which agreements have termination notice under 30 days? |  |  |  |  |  |
| 2 | Which agreements require exactly 30 days termination notice? |  |  |  |  |  |
| 3 | Which agreements require more than 45 days notice? |  |  |  |  |  |
| 4 | Summarize key obligations in Vendor Agreement A. |  |  |  |  |  |
| 5 | What are the payment obligations in SaaS Agreement C? |  |  |  |  |  |
| 6 | Which contracts mention confidentiality obligations? |  |  |  |  |  |
| 7 | Which contracts include automatic renewal? |  |  |  |  |  |
| 8 | Which contracts require written approval before assignment? |  |  |  |  |  |
| 9 | Which agreements have liability cap below $100,000? |  |  |  |  |  |
| 10 | Which agreements have no liability cap? |  |  |  |  |  |
| 11 | Which policies were updated most recently? |  |  |  |  |  |
| 12 | Summarize the latest version of the security policy. |  |  |  |  |  |
| 13 | What changed between the old and latest policy version? |  |  |  |  |  |
| 14 | Which documents mention audit rights? |  |  |  |  |  |
| 15 | Which agreements include a data processing clause? |  |  |  |  |  |
| 16 | Which agreements can be terminated for convenience? |  |  |  |  |  |
| 17 | Which agreements have governing law in California? |  |  |  |  |  |
| 18 | Which contracts require insurance coverage? |  |  |  |  |  |
| 19 | Ask about a Company B-only document while signed in as Company A. | No Company B source should appear | Tenant isolation enforced |  |  |  |
| 20 | Ask about an old version after uploading a newer version. | Latest version only | Staleness avoided |  |  |  |

## Evidence Summary

| Metric | Value |
| --- | --- |
| Total evaluated queries | 20 |
| Failed wrong-document queries |  |
| Wrong-doc rate |  |
| Failed stale-version queries |  |
| Notes |  |

## Observed Retrieval Failure Mode

Qua test, failure mode quan trong nhat khong nam o LLM generation ma nam o retrieval layer:

- Query document-specific nhu `Summarize the key obligations in Vendor Agreement A` co the retrieve them Security Policy, Employment Contract, NDA do semantic similarity.
- Query filtered-list nhu `Which agreements have termination notice under 30 days?` co the bo sot tai lieu dung neu relevant document bi rank thap.
- Tenant isolation phai duoc enforce o retrieval stage; khong du de LLM tu bo qua source sai tenant.

Mitigation hien tai trong code:

- Bedrock retrieve filter gom `workspace_id`, `tenant_name`, `is_latest=true`.
- Neu query nhac ro document name, AI backend resolve `document_id` latest tu DynamoDB va them `document_id` vao retrieval filter.
- Sau retrieval, backend hau kiem metadata va loai chunk sai workspace/tenant/document/latest truoc khi prompt model.
- Dynamic top-k: document-specific query lay toi da 6 chunks, filtered-list query lay toi da 20 chunks, query thuong lay toi da 8 chunks.
- Prompt cam liet ke non-qualifying/cross-tenant documents neu user khong hoi.

## Expected Demo Claim

Use this wording only after filling the table:

```text
We tested 20 document-search queries. Wrong-doc rate was <X>%.
The system mitigates document confusion with workspace metadata filter,
server-side workspace ownership checks, post-retrieval metadata validation,
strict citations, and filtered-list prompt rules.
Freshness is handled with S3 versioning, DynamoDB document_version/is_latest,
Bedrock metadata sidecars, upload_completed_at, and post-retrieval exclusion
of chunks marked is_latest=false.
```
