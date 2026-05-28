data "aws_caller_identity" "current" {}

# --- IAM Role for Bedrock KB ---
resource "aws_iam_role" "bedrock_kb_role" {
  name = "${local.resource_base_name}-ai-bedrock-kb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_kb_policy" {
  name = "${local.resource_base_name}-ai-bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = local.embedding_model_arn
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = "arn:aws:aoss:${var.aws_region}:${data.aws_caller_identity.current.account_id}:collection/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.dochub_data.arn, "${aws_s3_bucket.dochub_data.arn}/*"]
      }
    ]
  })
}

# --- OpenSearch Serverless Collection ---
resource "aws_opensearchserverless_security_policy" "kb_encryption" {
  name = "${local.resource_base_name}-ai-kb-enc"
  type = "encryption"
  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${local.oss_collection_name}"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "kb_network" {
  name = "${local.resource_base_name}-ai-kb-net"
  type = "network"
  policy = jsonencode([{
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${local.oss_collection_name}"]
      }, {
      ResourceType = "dashboard"
      Resource     = ["collection/${local.oss_collection_name}"]
    }]
    AllowFromPublic = true
  }])
}

resource "aws_opensearchserverless_access_policy" "kb_access" {
  name = "${local.resource_base_name}-ai-kb-access"
  type = "data"
  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "index"
        Resource     = ["index/${local.oss_collection_name}/*"]
        Permission   = ["aoss:CreateIndex", "aoss:DeleteIndex", "aoss:UpdateIndex", "aoss:DescribeIndex", "aoss:ReadDocument", "aoss:WriteDocument"]
      },
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.oss_collection_name}"]
        Permission   = ["aoss:CreateCollectionItems", "aoss:DeleteCollectionItems", "aoss:UpdateCollectionItems", "aoss:DescribeCollectionItems"]
      }
    ]
    Principal = concat([aws_iam_role.bedrock_kb_role.arn], var.opensearch_index_admin_arns)
  }])
}

resource "aws_opensearchserverless_collection" "kb" {
  name = local.oss_collection_name
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.kb_encryption,
    aws_opensearchserverless_security_policy.kb_network,
    aws_opensearchserverless_access_policy.kb_access
  ]
}

# --- Bootstrap OpenSearch vector index ---
resource "null_resource" "create_oss_index" {
  provisioner "local-exec" {
    command = "python ${path.module}/scripts/create_oss_index.py"
    environment = {
      COLLECTION_ENDPOINT = aws_opensearchserverless_collection.kb.collection_endpoint
      INDEX_NAME          = local.oss_index_name
      AWS_REGION          = var.aws_region
      VECTOR_DIMENSION    = tostring(var.embedding_vector_dimension)
    }
  }

  triggers = {
    collection_id = aws_opensearchserverless_collection.kb.id
  }

  depends_on = [
    aws_opensearchserverless_collection.kb,
    aws_opensearchserverless_access_policy.kb_access
  ]
}

# --- Bedrock Knowledge Base ---
resource "aws_bedrockagent_knowledge_base" "dochub_kb" {
  name     = "${local.resource_base_name}-ai-kb"
  role_arn = aws_iam_role.bedrock_kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.kb.arn
      vector_index_name = local.oss_index_name
      field_mapping {
        vector_field   = "embedding"
        text_field     = "text"
        metadata_field = "metadata"
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.bedrock_kb_policy,
    null_resource.create_oss_index
  ]
}

# --- Bedrock Data Source ---
resource "aws_bedrockagent_data_source" "dochub_ds" {
  name                 = "${local.resource_base_name}-ai-s3-datasource"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.dochub_kb.id
  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.dochub_data.arn
    }
  }
}
