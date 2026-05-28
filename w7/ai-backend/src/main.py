import base64
import hashlib
import hmac
import json
import re
import time
import traceback

import boto3
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from src.config import Config
from src.rag_pipeline import RAGPipeline

TENANT_ID_RE = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")
METRIC_NAMESPACE = Config.METRIC_NAMESPACE
AUTH_TOKEN_TTL_SECONDS = 12 * 60 * 60

app = FastAPI(title="AI Backend", version="1.0.0")

workspace_table = boto3.resource("dynamodb", region_name=Config.AWS_REGION).Table(Config.WORKSPACE_TABLE)
cloudwatch = boto3.client("cloudwatch", region_name=Config.AWS_REGION)
pipeline = RAGPipeline(
    knowledge_base_id=Config.BEDROCK_KB_ID,
    model_id=Config.BEDROCK_MODEL_ID,
    min_retrieval_score=Config.MIN_RETRIEVAL_SCORE,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=Config.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    query: str = Field(min_length=1, max_length=4000)
    workspace_id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$")


def validate_tenant_id(tenant_id: str | None) -> str:
    if not tenant_id or not TENANT_ID_RE.match(tenant_id):
        raise HTTPException(status_code=401, detail="Missing or invalid tenant context")
    return tenant_id


def b64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def verify_auth_token(token: str | None) -> dict:
    if not token or "." not in token:
        raise HTTPException(status_code=401, detail="Missing or invalid authorization token")

    payload_b64, signature_b64 = token.split(".", 1)
    expected_signature = hmac.new(
        Config.DEMO_AUTH_SECRET.encode("utf-8"),
        payload_b64.encode("utf-8"),
        hashlib.sha256,
    ).digest()
    try:
        actual_signature = b64url_decode(signature_b64)
        payload = json.loads(b64url_decode(payload_b64).decode("utf-8"))
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Missing or invalid authorization token") from exc

    if not hmac.compare_digest(expected_signature, actual_signature):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization token")
    if int(payload.get("exp", 0)) < int(time.time()):
        raise HTTPException(status_code=401, detail="Session expired. Please sign in again.")
    if not TENANT_ID_RE.match(payload.get("tenant_id", "")):
        raise HTTPException(status_code=401, detail="Missing or invalid tenant context")
    if payload.get("role") not in {"company_admin", "member"}:
        raise HTTPException(status_code=401, detail="Missing or invalid authorization token")
    return payload


def get_session(authorization: str | None) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization token")
    return verify_auth_token(authorization.removeprefix("Bearer ").strip())


def workspace_belongs_to_tenant(workspace_id: str, tenant_id: str) -> bool:
    response = workspace_table.get_item(Key={"workspace_id": workspace_id})
    item = response.get("Item")
    return bool(item and item.get("tenant_name") == tenant_id)


def put_metric(metric_name: str, value: float, unit: str) -> None:
    try:
        cloudwatch.put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=[
                {
                    "MetricName": metric_name,
                    "Value": value,
                    "Unit": unit,
                    "Dimensions": [
                        {"Name": "Service", "Value": "AIBackend"},
                    ],
                }
            ],
        )
    except Exception as exc:
        print(f"Failed to publish CloudWatch metric {metric_name}: {exc}")


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/chat")
def chat_with_docs(request: ChatRequest, authorization: str | None = Header(default=None)):
    session = get_session(authorization)
    tenant_id = session["tenant_id"]
    if not workspace_belongs_to_tenant(request.workspace_id, tenant_id):
        raise HTTPException(status_code=403, detail="Workspace does not belong to this tenant")

    started_at = time.monotonic()
    try:
        response = pipeline.retrieve_and_generate(
            query=request.query,
            workspace_id=request.workspace_id,
            tenant_id=tenant_id,
            top_k=20,
        )
        latency_ms = (time.monotonic() - started_at) * 1000
        put_metric("ChatRequests", 1, "Count")
        put_metric("ChatLatencyMs", latency_ms, "Milliseconds")
        return {
            "answer": response.answer,
            "sources": response.sources,
        }
    except Exception as exc:
        latency_ms = (time.monotonic() - started_at) * 1000
        put_metric("ChatErrors", 1, "Count")
        put_metric("ChatLatencyMs", latency_ms, "Milliseconds")
        print(f"Chat generation failed: {exc}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="AI backend failed to generate a response") from exc


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
