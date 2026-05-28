import json
import os
import urllib.parse
from datetime import datetime, timezone

import boto3


dynamodb = boto3.client("dynamodb")
bedrock_agent = boto3.client("bedrock-agent")
cloudwatch = boto3.client("cloudwatch")
s3_client = boto3.client("s3")

DOCUMENT_TABLE = os.environ.get("DOCUMENT_TABLE")
BEDROCK_KB_ID = os.environ.get("BEDROCK_KB_ID")
BEDROCK_DS_ID = os.environ.get("BEDROCK_DS_ID")

TERMINAL_STATUSES = {"READY", "ERROR"}
IN_PROGRESS_BEDROCK_STATUSES = {"STARTING", "IN_PROGRESS", "SYNCING"}
READY_BEDROCK_STATUSES = {"COMPLETE", "COMPLETED"}
ERROR_BEDROCK_STATUSES = {"FAILED", "STOPPED", "STOPPING"}
METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "DocHub")


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def handler(event, context):
    print("Event Handler Received:", json.dumps(event))

    if "Records" in event:
        for record in event.get("Records", []):
            if record.get("eventSource") == "aws:s3" and "ObjectCreated" in record.get("eventName", ""):
                handle_s3_upload(record)
        return {"statusCode": 200, "body": "S3 Event Processed"}

    if event.get("source") == "aws.bedrock":
        handle_bedrock_ingestion_event(event)
        return {"statusCode": 200, "body": "Bedrock Event Processed"}

    return {"statusCode": 200, "body": "Unknown Event, Ignored"}


def handle_s3_upload(record):
    bucket = record["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(record["s3"]["object"]["key"], encoding="utf-8")
    s3_version_id = record["s3"]["object"].get("versionId", "")

    if key.endswith(".metadata.json"):
        print("Ignoring metadata file upload.")
        return

    parts = key.split("/")
    if len(parts) < 3:
        print(f"Ignoring object with unexpected key format: {key}")
        return

    document_id = parts[1]
    print(f"File uploaded to S3: s3://{bucket}/{key}; document_id={document_id}")

    existing_document = get_document(document_id)
    if not existing_document:
        print(f"Document {document_id} not found in DynamoDB; upload event ignored.")
        return

    existing_status = get_string(existing_document, "status")
    existing_job_id = get_string(existing_document, "ingestion_job_id")
    if existing_status in TERMINAL_STATUSES or (existing_status == "INDEXING" and existing_job_id):
        print(f"Document {document_id} is already {existing_status}; duplicate upload event ignored.")
        return

    uploaded_at = utc_now()
    upload_attributes = {
        "status": "UPLOADED",
        "upload_completed_at": uploaded_at,
        "updated_at": uploaded_at,
    }
    if s3_version_id:
        upload_attributes["s3_version_id"] = s3_version_id

    update_document(
        document_id,
        upload_attributes,
    )
    update_metadata_sidecar(bucket, key, existing_document, uploaded_at, s3_version_id)
    put_count_metric("DocumentsUploaded")

    try:
        response = bedrock_agent.start_ingestion_job(
            knowledgeBaseId=BEDROCK_KB_ID,
            dataSourceId=BEDROCK_DS_ID,
            description=f"Auto-sync for document {document_id}",
        )
        job_id = response["ingestionJob"]["ingestionJobId"]
        started_at = utc_now()

        update_document(
            document_id,
            {
                "status": "INDEXING",
                "ingestion_job_id": job_id,
                "ingestion_started_at": started_at,
                "updated_at": started_at,
            },
        )
        print(f"Started Bedrock ingestion job {job_id} for document {document_id}.")
    except Exception as exc:
        failed_at = utc_now()
        update_document(
            document_id,
            {
                "status": "ERROR",
                "error_message": str(exc)[:1000],
                "updated_at": failed_at,
            },
        )
        print(f"Failed to start Bedrock ingestion for document {document_id}: {exc}")


def handle_bedrock_ingestion_event(event):
    detail = event.get("detail", {})
    job_id = normalize_bedrock_job_id(first_detail_value(detail, "ingestionJobId", "ingestionJobArn", "jobId"))
    kb_id = first_detail_value(detail, "knowledgeBaseId", "knowledgeBaseArn")
    bedrock_status = first_detail_value(detail, "status", "ingestionJobStatus")

    print(f"Bedrock ingestion event: job_id={job_id}, knowledge_base={kb_id}, status={bedrock_status}")

    if not job_id or not bedrock_status:
        print("Bedrock event missing ingestion job id or status; ignored.")
        return

    normalized_status = str(bedrock_status).upper()
    new_status = map_bedrock_status(normalized_status)
    if not new_status:
        print(f"Bedrock status {normalized_status} is not mapped; ignored.")
        return

    for document_id in scan_document_ids_by_job(job_id):
        now = utc_now()
        attributes = {
            "status": new_status,
            "bedrock_ingestion_status": normalized_status,
            "updated_at": now,
        }

        if new_status in TERMINAL_STATUSES:
            attributes["ingestion_completed_at"] = now

        if new_status == "ERROR":
            failure_reasons = detail.get("failureReasons") or detail.get("failureReason")
            if failure_reasons:
                attributes["error_message"] = json.dumps(failure_reasons)[:1000]

        update_document(document_id, attributes)
        print(f"Updated document {document_id} to {new_status} from Bedrock job {job_id}.")


def get_document(document_id):
    response = dynamodb.get_item(
        TableName=DOCUMENT_TABLE,
        Key={"document_id": {"S": document_id}},
    )
    return response.get("Item")


def get_string(item, attribute_name):
    value = item.get(attribute_name, {})
    return value.get("S")


def update_metadata_sidecar(bucket, key, document, uploaded_at, s3_version_id):
    metadata_key = f"{key}.metadata.json"
    try:
        response = s3_client.get_object(Bucket=bucket, Key=metadata_key)
        metadata_content = json.loads(response["Body"].read().decode("utf-8"))
    except Exception as exc:
        print(f"Could not read metadata sidecar {metadata_key}; rebuilding minimal metadata: {exc}")
        metadata_content = {"metadataAttributes": {}}

    attributes = metadata_content.setdefault("metadataAttributes", {})
    attributes.update(
        {
            "workspace_id": get_string(document, "workspace_id") or key.split("/")[0],
            "tenant_name": get_string(document, "tenant_name") or "",
            "document_id": get_string(document, "document_id") or key.split("/")[1],
            "filename": get_string(document, "filename") or key.split("/")[-1],
            "document_version": get_string(document, "document_version") or "1",
            "is_latest": get_string(document, "is_latest") or "true",
            "document_created_at": get_string(document, "created_at") or uploaded_at,
            "upload_completed_at": uploaded_at,
        }
    )
    if s3_version_id:
        attributes["s3_version_id"] = s3_version_id

    s3_client.put_object(
        Bucket=bucket,
        Key=metadata_key,
        Body=json.dumps(metadata_content),
        ContentType="application/json",
    )


def update_document(document_id, attributes):
    names = {}
    values = {}
    assignments = []

    for index, (attribute_name, attribute_value) in enumerate(attributes.items()):
        name_key = f"#a{index}"
        value_key = f":v{index}"
        names[name_key] = attribute_name
        values[value_key] = {"S": str(attribute_value)}
        assignments.append(f"{name_key} = {value_key}")

    dynamodb.update_item(
        TableName=DOCUMENT_TABLE,
        Key={"document_id": {"S": document_id}},
        UpdateExpression="SET " + ", ".join(assignments),
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
    )


def first_detail_value(detail, *keys):
    for key in keys:
        value = detail.get(key)
        if value:
            return value
    return None


def normalize_bedrock_job_id(value):
    if not value:
        return None
    return str(value).rstrip("/").split("/")[-1]


def map_bedrock_status(status):
    if status in READY_BEDROCK_STATUSES:
        return "READY"
    if status in ERROR_BEDROCK_STATUSES:
        return "ERROR"
    if status in IN_PROGRESS_BEDROCK_STATUSES:
        return "INDEXING"
    return None


def scan_document_ids_by_job(job_id):
    paginator = dynamodb.get_paginator("scan")
    for page in paginator.paginate(
        TableName=DOCUMENT_TABLE,
        FilterExpression="ingestion_job_id = :j",
        ExpressionAttributeValues={":j": {"S": job_id}},
        ProjectionExpression="document_id",
    ):
        for item in page.get("Items", []):
            document_id = get_string(item, "document_id")
            if document_id:
                yield document_id


def put_count_metric(metric_name):
    try:
        cloudwatch.put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=[
                {
                    "MetricName": metric_name,
                    "Value": 1,
                    "Unit": "Count",
                    "Dimensions": [
                        {"Name": "Service", "Value": "EventHandler"},
                    ],
                }
            ],
        )
    except Exception as exc:
        print(f"Failed to publish CloudWatch metric {metric_name}: {exc}")
