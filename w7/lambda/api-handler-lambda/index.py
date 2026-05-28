import json
import os
import re
import uuid
import base64
import hashlib
import hmac
import time
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Attr
from botocore.config import Config
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
AWS_REGION = os.environ.get("AWS_REGION", "us-west-2")
bedrock_agent = boto3.client("bedrock-agent", region_name=AWS_REGION)
s3_client = boto3.client(
    "s3",
    region_name=AWS_REGION,
    config=Config(signature_version="s3v4", s3={"addressing_style": "virtual"}),
)

WORKSPACE_TABLE = os.environ.get("WORKSPACE_TABLE")
DOCUMENT_TABLE = os.environ.get("DOCUMENT_TABLE")
COMPANY_TABLE = os.environ.get("COMPANY_TABLE")
USER_TABLE = os.environ.get("USER_TABLE")
S3_BUCKET = os.environ.get("S3_BUCKET")
ALLOWED_ORIGIN = os.environ.get("ALLOWED_ORIGIN", "*")
BEDROCK_KB_ID = os.environ.get("BEDROCK_KB_ID")
BEDROCK_DS_ID = os.environ.get("BEDROCK_DS_ID")
DEMO_AUTH_SECRET = os.environ.get("DEMO_AUTH_SECRET", "dochub-demo-auth-secret")

TENANT_ID_RE = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")
WORKSPACE_ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
ALLOWED_EXTENSIONS = {".pdf", ".docx"}
IN_PROGRESS_BEDROCK_STATUSES = {"STARTING", "IN_PROGRESS", "SYNCING"}
READY_BEDROCK_STATUSES = {"COMPLETE", "COMPLETED"}
ERROR_BEDROCK_STATUSES = {"FAILED", "STOPPED", "STOPPING"}
AUTH_TOKEN_TTL_SECONDS = 12 * 60 * 60


def get_body(event):
    if event.get("body"):
        return json.loads(event["body"])
    return {}


def get_header(event, name):
    headers = event.get("headers") or {}
    target = name.lower()
    for key, value in headers.items():
        if key.lower() == target:
            return value
    return None


def get_tenant_id(event):
    session = get_session(event)
    if not session:
        return None
    return session["tenant_id"]


def create_response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
            "Vary": "Origin",
        },
        "body": json.dumps(body, default=str),
    }


def b64url_encode(value):
    return base64.urlsafe_b64encode(value).decode("utf-8").rstrip("=")


def b64url_decode(value):
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def hash_password(password):
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def user_table():
    return dynamodb.Table(USER_TABLE)


def company_table():
    return dynamodb.Table(COMPANY_TABLE)


def get_user(email):
    if not USER_TABLE:
        return None
    response = user_table().get_item(Key={"email": email})
    return response.get("Item")


def public_user(user):
    return {
        "email": user.get("email"),
        "tenant_id": user.get("tenant_id"),
        "company_name": user.get("company_name"),
        "role": user.get("role"),
        "status": user.get("status", "active"),
        "is_demo": bool(user.get("is_demo", False)),
        "created_at": user.get("created_at"),
    }


def create_auth_token(account):
    now = int(time.time())
    payload = {
        "email": account["email"],
        "tenant_id": account["tenant_id"],
        "company_name": account["company_name"],
        "role": account["role"],
        "iat": now,
        "exp": now + AUTH_TOKEN_TTL_SECONDS,
    }
    payload_b64 = b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature = hmac.new(DEMO_AUTH_SECRET.encode("utf-8"), payload_b64.encode("utf-8"), hashlib.sha256).digest()
    return f"{payload_b64}.{b64url_encode(signature)}"


def verify_auth_token(token):
    if not token or "." not in token:
        return None
    payload_b64, signature_b64 = token.split(".", 1)
    expected_signature = hmac.new(
        DEMO_AUTH_SECRET.encode("utf-8"),
        payload_b64.encode("utf-8"),
        hashlib.sha256,
    ).digest()
    try:
        actual_signature = b64url_decode(signature_b64)
    except Exception:
        return None
    if not hmac.compare_digest(expected_signature, actual_signature):
        return None
    try:
        payload = json.loads(b64url_decode(payload_b64).decode("utf-8"))
    except Exception:
        return None
    if int(payload.get("exp", 0)) < int(time.time()):
        return None
    if not TENANT_ID_RE.match(payload.get("tenant_id", "")):
        return None
    if payload.get("role") not in {"company_admin", "member"}:
        return None
    return payload


def get_session(event):
    auth_header = get_header(event, "Authorization") or ""
    if not auth_header.startswith("Bearer "):
        return None
    return verify_auth_token(auth_header.removeprefix("Bearer ").strip())


def login(event):
    body = get_body(event)
    email = str(body.get("email", "")).strip().lower()
    password = str(body.get("password", ""))

    account = get_user(email)
    if (
        not account
        or account.get("status", "active") != "active"
        or not hmac.compare_digest(account.get("password_hash", ""), hash_password(password))
    ):
        return create_response(401, {"error": "Invalid email or password"})

    account_payload = {
        "email": email,
        "tenant_id": account["tenant_id"],
        "company_name": account["company_name"],
        "role": account["role"],
    }
    token = create_auth_token(account_payload)
    return create_response(
        200,
        {
            "token": token,
            "user": account_payload,
            "expires_in": AUTH_TOKEN_TTL_SECONDS,
        },
    )


def list_login_accounts(event):
    if not USER_TABLE:
        return create_response(500, {"error": "USER_TABLE is not configured"})

    response = user_table().scan()
    accounts = [
        public_user(user)
        for user in response.get("Items", [])
        if user.get("status", "active") == "active" and bool(user.get("is_demo", False))
    ]
    accounts.sort(key=lambda user: (user["company_name"], user["role"], user["email"]))
    return create_response(200, {"accounts": accounts})


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def require_session(event, roles=None):
    session = get_session(event)
    if not session:
        return None, create_response(401, {"error": "Missing or invalid tenant context"})
    if roles and session.get("role") not in roles:
        return None, create_response(403, {"error": "This operation requires a company admin account"})
    return session, None


def require_tenant(event, roles=None):
    session, error = require_session(event, roles)
    if error:
        return None, error
    return session["tenant_id"], None


def workspace_belongs_to_tenant(workspace_id, tenant_id):
    table = dynamodb.Table(WORKSPACE_TABLE)
    response = table.get_item(Key={"workspace_id": workspace_id})
    item = response.get("Item")
    return bool(item and item.get("tenant_name") == tenant_id)


def validate_workspace_id(workspace_id):
    return bool(workspace_id and WORKSPACE_ID_RE.match(workspace_id))


def tenant_slug(tenant_id):
    return re.sub(r"[^a-z0-9]+", "-", tenant_id.lower()).strip("-")[:24] or "tenant"


def company_slug(company_name):
    slug = re.sub(r"[^a-z0-9]+", "-", company_name.lower()).strip("-")
    return slug[:48].strip("-") or f"company-{uuid.uuid4().hex[:8]}"


def build_workspace_id(tenant_id, workspace_id):
    base_id = str(workspace_id or "").strip().lower()
    if not validate_workspace_id(base_id):
        return None
    prefix = tenant_slug(tenant_id)
    if base_id.startswith(f"{prefix}-"):
        return base_id
    namespaced = f"{prefix}-{base_id}"
    if len(namespaced) > 63:
        namespaced = namespaced[:63].rstrip("-")
    return namespaced


def get_current_company(event):
    session, error = require_session(event)
    if error:
        return error

    tenant_id = session["tenant_id"]
    company = {
        "tenant_id": tenant_id,
        "name": session.get("company_name", tenant_id),
        "status": "active",
    }

    if COMPANY_TABLE:
        response = company_table().get_item(Key={"tenant_id": tenant_id})
        if response.get("Item"):
            item = response["Item"]
            company = {
                "tenant_id": item.get("tenant_id", tenant_id),
                "name": item.get("name", session.get("company_name", tenant_id)),
                "status": item.get("status", "active"),
                "is_demo": bool(item.get("is_demo", False)),
            }

    users = []
    if USER_TABLE:
        response = user_table().scan(FilterExpression=Attr("tenant_id").eq(tenant_id))
        users = [public_user(user) for user in response.get("Items", []) if user.get("status", "active") == "active"]
        users.sort(key=lambda user: (user["role"], user["email"]))

    return create_response(200, {"company": company, "users": users})


def create_company_user(event):
    session, error = require_session(event, roles={"company_admin"})
    if error:
        return error
    if not USER_TABLE:
        return create_response(500, {"error": "USER_TABLE is not configured"})

    body = get_body(event)
    email = str(body.get("email", "")).strip().lower()
    password = str(body.get("password", ""))
    role = str(body.get("role", "member")).strip()

    if not EMAIL_RE.match(email):
        return create_response(400, {"error": "Valid email is required"})
    if len(password) < 6:
        return create_response(400, {"error": "Password must have at least 6 characters"})
    if role not in {"company_admin", "member"}:
        return create_response(400, {"error": "role must be company_admin or member"})

    now = utc_now()
    item = {
        "email": email,
        "password_hash": hash_password(password),
        "tenant_id": session["tenant_id"],
        "company_name": session.get("company_name", session["tenant_id"]),
        "role": role,
        "status": "active",
        "is_demo": False,
        "created_at": now,
        "created_by": session.get("email", "unknown"),
    }

    try:
        user_table().put_item(Item=item, ConditionExpression="attribute_not_exists(email)")
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return create_response(409, {"error": "User already exists"})
        raise

    return create_response(201, {"message": "User created", "user": public_user(item)})


def register_company(event):
    if not COMPANY_TABLE or not USER_TABLE:
        return create_response(500, {"error": "COMPANY_TABLE and USER_TABLE must be configured"})

    body = get_body(event)
    company_name = str(body.get("company_name", "")).strip()
    email = str(body.get("admin_email", body.get("email", ""))).strip().lower()
    password = str(body.get("admin_password", body.get("password", "")))
    requested_tenant_id = str(body.get("tenant_id", "")).strip().lower()

    if len(company_name) < 2:
        return create_response(400, {"error": "Company name is required"})
    if not EMAIL_RE.match(email):
        return create_response(400, {"error": "Valid admin email is required"})
    if len(password) < 6:
        return create_response(400, {"error": "Password must have at least 6 characters"})

    tenant_id = requested_tenant_id or company_slug(company_name)
    if not TENANT_ID_RE.match(tenant_id):
        return create_response(400, {"error": "tenant_id can contain only letters, numbers, underscores, or hyphens"})

    now = utc_now()
    company_item = {
        "tenant_id": tenant_id,
        "name": company_name,
        "status": "active",
        "is_demo": False,
        "created_at": now,
    }
    user_item = {
        "email": email,
        "password_hash": hash_password(password),
        "tenant_id": tenant_id,
        "company_name": company_name,
        "role": "company_admin",
        "status": "active",
        "is_demo": False,
        "created_at": now,
        "created_by": "company_registration",
    }

    try:
        company_table().put_item(Item=company_item, ConditionExpression="attribute_not_exists(tenant_id)")
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return create_response(409, {"error": "Company already exists. Choose a different company name."})
        raise

    try:
        user_table().put_item(Item=user_item, ConditionExpression="attribute_not_exists(email)")
    except ClientError as exc:
        company_table().delete_item(Key={"tenant_id": tenant_id})
        if exc.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return create_response(409, {"error": "Admin email already exists"})
        raise

    account_payload = {
        "email": email,
        "tenant_id": tenant_id,
        "company_name": company_name,
        "role": "company_admin",
    }
    return create_response(
        201,
        {
            "message": "Company registered",
            "company": company_item,
            "user": account_payload,
            "token": create_auth_token(account_payload),
            "expires_in": AUTH_TOKEN_TTL_SECONDS,
        },
    )


def delete_company_user(event):
    session, error = require_session(event, roles={"company_admin"})
    if error:
        return error
    if not USER_TABLE:
        return create_response(500, {"error": "USER_TABLE is not configured"})

    query_params = event.get("queryStringParameters") or {}
    email = str(query_params.get("email", "")).strip().lower()

    if not EMAIL_RE.match(email):
        return create_response(400, {"error": "Valid email is required"})
    if email == session.get("email"):
        return create_response(400, {"error": "You cannot delete your own signed-in account"})

    response = user_table().get_item(Key={"email": email})
    user = response.get("Item")
    if not user or user.get("status", "active") != "active":
        return create_response(404, {"error": "User not found"})
    if user.get("tenant_id") != session["tenant_id"]:
        return create_response(403, {"error": "User does not belong to this company"})

    if user.get("role") == "company_admin":
        admins_response = user_table().scan(
            FilterExpression=Attr("tenant_id").eq(session["tenant_id"])
            & Attr("role").eq("company_admin")
            & Attr("status").eq("active")
        )
        active_admins = [item for item in admins_response.get("Items", []) if item.get("email") != email]
        if not active_admins:
            return create_response(400, {"error": "A company must keep at least one active admin"})

    user_table().delete_item(Key={"email": email})
    return create_response(200, {"message": "User deleted", "email": email})


def validate_filename(filename):
    if not filename or "/" in filename or "\\" in filename:
        return False
    lower_name = filename.lower()
    return any(lower_name.endswith(extension) for extension in ALLOWED_EXTENSIONS)


def handler(event, context):
    print("API Handler Received Event:", json.dumps(event))

    path = event.get("resource", event.get("path", ""))
    method = event.get("httpMethod", "")

    try:
        if path == "/auth/login" and method == "POST":
            return login(event)
        if path == "/auth/accounts" and method == "GET":
            return list_login_accounts(event)
        if path == "/companies/register" and method == "POST":
            return register_company(event)
        if path == "/companies/current" and method == "GET":
            return get_current_company(event)
        if path == "/companies/users" and method == "POST":
            return create_company_user(event)
        if path == "/companies/users" and method == "DELETE":
            return delete_company_user(event)
        if path == "/workspaces" and method == "GET":
            return get_workspaces(event)
        if path == "/workspaces" and method == "POST":
            return create_workspace(event)
        if path == "/workspaces" and method == "DELETE":
            return delete_workspace(event)
        if path == "/documents/upload" and method == "POST":
            return init_document_upload(event)
        if path == "/documents" and method == "GET":
            return get_documents(event)
        if path == "/documents" and method == "DELETE":
            return delete_document(event)
        return create_response(404, {"error": "Not Found"})
    except Exception as exc:
        print("Error:", str(exc))
        return create_response(500, {"error": "Internal Server Error"})


def get_workspaces(event):
    tenant_id, error = require_tenant(event)
    if error:
        return error

    table = dynamodb.Table(WORKSPACE_TABLE)
    response = table.scan(FilterExpression=Attr("tenant_name").eq(tenant_id))
    workspaces = response.get("Items", [])
    workspaces.sort(key=lambda workspace: workspace.get("created_at", ""), reverse=True)
    return create_response(200, {"workspaces": workspaces})


def create_workspace(event):
    tenant_id, error = require_tenant(event, roles={"company_admin"})
    if error:
        return error

    body = get_body(event)
    requested_workspace_id = body.get("workspace_id")
    display_name = str(body.get("workspace_name") or requested_workspace_id or "").strip()
    workspace_id = build_workspace_id(tenant_id, requested_workspace_id)

    if not workspace_id:
        return create_response(400, {"error": "workspace_id must be lowercase alphanumeric with optional hyphens"})

    table = dynamodb.Table(WORKSPACE_TABLE)
    item = {
        "workspace_id": workspace_id,
        "display_name": display_name or workspace_id,
        "tenant_name": tenant_id,
        "created_at": utc_now(),
    }
    try:
        table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(workspace_id)",
        )
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return create_response(409, {"error": "Workspace already exists"})
        raise
    return create_response(201, {"message": "Workspace created", "workspace": item})


def get_documents(event):
    tenant_id, error = require_tenant(event)
    if error:
        return error

    query_params = event.get("queryStringParameters") or {}
    workspace_id = query_params.get("workspace_id")

    if not validate_workspace_id(workspace_id):
        return create_response(400, {"error": "workspace_id is required"})

    if not workspace_belongs_to_tenant(workspace_id, tenant_id):
        return create_response(403, {"error": "Workspace does not belong to this tenant"})

    table = dynamodb.Table(DOCUMENT_TABLE)
    response = table.scan(FilterExpression=Attr("workspace_id").eq(workspace_id))
    documents = response.get("Items", [])

    refreshed_documents = []
    for document in documents:
        if document.get("tenant_name") != tenant_id:
            continue
        refreshed_documents.append(refresh_ingestion_status(document))

    return create_response(200, {"documents": refreshed_documents})


def init_document_upload(event):
    tenant_id, error = require_tenant(event)
    if error:
        return error

    body = get_body(event)
    workspace_id = body.get("workspace_id")
    filename = body.get("filename")

    if not validate_workspace_id(workspace_id):
        return create_response(400, {"error": "workspace_id is required"})
    if not validate_filename(filename):
        return create_response(400, {"error": "Only .pdf and .docx filenames are allowed"})
    if not workspace_belongs_to_tenant(workspace_id, tenant_id):
        return create_response(403, {"error": "Workspace does not belong to this tenant"})

    document_id = str(uuid.uuid4())
    s3_key = f"{workspace_id}/{document_id}/{filename}"
    metadata_key = f"{s3_key}.metadata.json"
    created_at = utc_now()

    table = dynamodb.Table(DOCUMENT_TABLE)
    document_version = str(next_document_version(table, tenant_id, workspace_id, filename))
    item = {
        "document_id": document_id,
        "workspace_id": workspace_id,
        "tenant_name": tenant_id,
        "filename": filename,
        "s3_key": s3_key,
        "status": "PENDING",
        "document_version": document_version,
        "is_latest": "true",
        "created_at": created_at,
    }
    table.put_item(Item=item)
    mark_previous_versions_not_latest(table, tenant_id, workspace_id, filename, document_id, created_at)

    metadata_content = {
        "metadataAttributes": {
            "workspace_id": workspace_id,
            "tenant_name": tenant_id,
            "document_id": document_id,
            "filename": filename,
            "document_version": document_version,
            "is_latest": "true",
            "document_created_at": created_at,
        }
    }
    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=metadata_key,
        Body=json.dumps(metadata_content),
        ContentType="application/json",
    )

    presigned_post = s3_client.generate_presigned_post(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Conditions=[
            ["content-length-range", 1, 10485760],
        ],
        ExpiresIn=300,
    )

    return create_response(
        200,
        {
            "document_id": document_id,
            "upload_url": presigned_post,
            "status": "PENDING",
            "document_version": document_version,
        },
    )


def next_document_version(table, tenant_id, workspace_id, filename):
    response = table.scan(
        FilterExpression=Attr("workspace_id").eq(workspace_id)
        & Attr("tenant_name").eq(tenant_id)
        & Attr("filename").eq(filename)
    )
    versions = []
    for document in response.get("Items", []):
        try:
            versions.append(int(document.get("document_version", "1")))
        except ValueError:
            versions.append(1)
    return (max(versions) if versions else 0) + 1


def mark_previous_versions_not_latest(table, tenant_id, workspace_id, filename, latest_document_id, superseded_at):
    response = table.scan(
        FilterExpression=Attr("workspace_id").eq(workspace_id)
        & Attr("tenant_name").eq(tenant_id)
        & Attr("filename").eq(filename)
    )
    for document in response.get("Items", []):
        document_id = document.get("document_id")
        if document_id == latest_document_id or document.get("is_latest") == "false":
            continue

        update_document(
            document_id,
            {
                "is_latest": "false",
                "superseded_by": latest_document_id,
                "superseded_at": superseded_at,
                "updated_at": superseded_at,
            },
        )
        update_metadata_latest_flag(document, latest_document_id, superseded_at)


def update_metadata_latest_flag(document, latest_document_id, superseded_at):
    s3_key = document.get("s3_key")
    if not s3_key:
        return

    metadata_key = f"{s3_key}.metadata.json"
    try:
        response = s3_client.get_object(Bucket=S3_BUCKET, Key=metadata_key)
        metadata_content = json.loads(response["Body"].read().decode("utf-8"))
    except ClientError as exc:
        print(f"Could not update stale metadata sidecar {metadata_key}: {exc}")
        return

    attributes = metadata_content.setdefault("metadataAttributes", {})
    attributes["is_latest"] = "false"
    attributes["superseded_by"] = latest_document_id
    attributes["superseded_at"] = superseded_at

    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key=metadata_key,
        Body=json.dumps(metadata_content),
        ContentType="application/json",
    )


def delete_document(event):
    tenant_id, error = require_tenant(event, roles={"company_admin"})
    if error:
        return error

    query_params = event.get("queryStringParameters") or {}
    document_id = query_params.get("document_id")
    if not document_id:
        return create_response(400, {"error": "document_id is required"})

    table = dynamodb.Table(DOCUMENT_TABLE)
    response = table.get_item(Key={"document_id": document_id})
    document = response.get("Item")
    if not document:
        return create_response(404, {"error": "Document not found"})
    if document.get("tenant_name") != tenant_id:
        return create_response(403, {"error": "Document does not belong to this tenant"})

    delete_s3_objects_for_document(document)
    table.delete_item(Key={"document_id": document_id})
    start_background_ingestion(f"Delete sync for document {document_id}")
    return create_response(200, {"message": "Document deleted", "document_id": document_id})


def delete_workspace(event):
    tenant_id, error = require_tenant(event, roles={"company_admin"})
    if error:
        return error

    query_params = event.get("queryStringParameters") or {}
    workspace_id = query_params.get("workspace_id")
    if not validate_workspace_id(workspace_id):
        return create_response(400, {"error": "workspace_id is required"})
    if not workspace_belongs_to_tenant(workspace_id, tenant_id):
        return create_response(403, {"error": "Workspace does not belong to this tenant"})

    documents_table = dynamodb.Table(DOCUMENT_TABLE)
    response = documents_table.scan(
        FilterExpression=Attr("workspace_id").eq(workspace_id) & Attr("tenant_name").eq(tenant_id)
    )
    deleted_documents = 0
    for document in response.get("Items", []):
        delete_s3_objects_for_document(document)
        documents_table.delete_item(Key={"document_id": document["document_id"]})
        deleted_documents += 1

    workspace_table = dynamodb.Table(WORKSPACE_TABLE)
    workspace_table.delete_item(Key={"workspace_id": workspace_id})
    start_background_ingestion(f"Delete sync for workspace {workspace_id}")
    return create_response(
        200,
        {
            "message": "Workspace deleted",
            "workspace_id": workspace_id,
            "deleted_documents": deleted_documents,
        },
    )


def delete_s3_objects_for_document(document):
    s3_key = document.get("s3_key")
    if not s3_key:
        return

    for key in (s3_key, f"{s3_key}.metadata.json"):
        try:
            s3_client.delete_object(Bucket=S3_BUCKET, Key=key)
        except ClientError as exc:
            print(f"Failed to delete s3://{S3_BUCKET}/{key}: {exc}")


def refresh_ingestion_status(document):
    if document.get("status") not in {"PENDING", "UPLOADED", "INDEXING"}:
        return document

    job_id = document.get("ingestion_job_id")
    if not job_id or not BEDROCK_KB_ID or not BEDROCK_DS_ID:
        return document

    try:
        response = bedrock_agent.get_ingestion_job(
            knowledgeBaseId=BEDROCK_KB_ID,
            dataSourceId=BEDROCK_DS_ID,
            ingestionJobId=job_id,
        )
    except ClientError as exc:
        print(f"Failed to refresh ingestion job {job_id}: {exc}")
        return document

    ingestion_job = response.get("ingestionJob", {})
    bedrock_status = str(ingestion_job.get("status", "")).upper()
    new_status = map_bedrock_status(bedrock_status)
    if not new_status or new_status == document.get("status"):
        document["bedrock_ingestion_status"] = bedrock_status
        return document

    attributes = {
        "status": new_status,
        "bedrock_ingestion_status": bedrock_status,
        "updated_at": utc_now(),
    }
    if new_status in {"READY", "ERROR"}:
        attributes["ingestion_completed_at"] = utc_now()
    if new_status == "ERROR" and ingestion_job.get("failureReasons"):
        attributes["error_message"] = json.dumps(ingestion_job["failureReasons"])[:1000]

    update_document(document["document_id"], attributes)
    document.update(attributes)
    return document


def start_background_ingestion(description):
    if not BEDROCK_KB_ID or not BEDROCK_DS_ID:
        return

    try:
        response = bedrock_agent.start_ingestion_job(
            knowledgeBaseId=BEDROCK_KB_ID,
            dataSourceId=BEDROCK_DS_ID,
            description=description,
        )
        job_id = response.get("ingestionJob", {}).get("ingestionJobId")
        print(f"Started Bedrock deletion sync job {job_id}: {description}")
    except ClientError as exc:
        print(f"Failed to start Bedrock deletion sync for {description}: {exc}")


def map_bedrock_status(status):
    if status in READY_BEDROCK_STATUSES:
        return "READY"
    if status in ERROR_BEDROCK_STATUSES:
        return "ERROR"
    if status in IN_PROGRESS_BEDROCK_STATUSES:
        return "INDEXING"
    return None


def update_document(document_id, attributes):
    names = {}
    values = {}
    assignments = []

    for index, (attribute_name, attribute_value) in enumerate(attributes.items()):
        name_key = f"#a{index}"
        value_key = f":v{index}"
        names[name_key] = attribute_name
        values[value_key] = str(attribute_value)
        assignments.append(f"{name_key} = {value_key}")

    table = dynamodb.Table(DOCUMENT_TABLE)
    table.update_item(
        Key={"document_id": document_id},
        UpdateExpression="SET " + ", ".join(assignments),
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
    )
