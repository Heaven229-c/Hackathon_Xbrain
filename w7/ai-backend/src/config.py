import os

from dotenv import load_dotenv

load_dotenv()


class Config:
    AWS_REGION = os.environ.get("AWS_REGION")
    BEDROCK_KB_ID = os.environ.get("BEDROCK_KB_ID")
    BEDROCK_DS_ID = os.environ.get("BEDROCK_DS_ID")
    BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID")
    MIN_RETRIEVAL_SCORE = float(os.environ.get("MIN_RETRIEVAL_SCORE", "0"))
    DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE")
    WORKSPACE_TABLE = os.environ.get("WORKSPACE_TABLE")
    DEMO_AUTH_SECRET = os.environ.get("DEMO_AUTH_SECRET", "dochub-demo-auth-secret")
    METRIC_NAMESPACE = os.environ.get("METRIC_NAMESPACE", "DocHub")
    ALLOWED_ORIGINS = [
        origin.strip()
        for origin in os.environ.get("ALLOWED_ORIGINS", "http://localhost:5173").split(",")
        if origin.strip()
    ]


required_values = {
    "AWS_REGION": Config.AWS_REGION,
    "BEDROCK_KB_ID": Config.BEDROCK_KB_ID,
    "BEDROCK_DS_ID": Config.BEDROCK_DS_ID,
    "BEDROCK_MODEL_ID": Config.BEDROCK_MODEL_ID,
    "DYNAMODB_TABLE": Config.DYNAMODB_TABLE,
    "WORKSPACE_TABLE": Config.WORKSPACE_TABLE,
}

missing_values = [name for name, value in required_values.items() if not value]
if missing_values:
    raise ValueError(f"Missing required environment variables: {', '.join(missing_values)}")
