provider "aws" {
  region = "us-west-2" # Change to your desired AWS region
}

# Variables
variable "s3_bucket_name" {
  description = "S3 Bucket name"
  type        = string
}

variable "dynamodb_name" {
  description = "Name of DynamoDB table"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

# S3 Logging Bucket (with encryption)
resource "aws_s3_bucket" "logging_bucket" {
  bucket = "${var.s3_bucket_name}-logging"
  versioning {
    enabled = true
  }
  acl = "private"
  force_destroy = true

  lifecycle {
    prevent_destroy = true
  }

  encryption {
    server_side_encryption_configuration {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }
  }

  logging {
    target_bucket = aws_s3_bucket.logging_bucket.bucket
    target_prefix = "bucket-logs/"
  }

  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

# S3 Bucket for processing
resource "aws_s3_bucket" "processing_bucket" {
  bucket = "${var.s3_bucket_name}-${terraform.workspace}"
  versioning {
    enabled = true
  }
  acl = "private"
  
  encryption {
    server_side_encryption_configuration {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }
  }

  notification {
    lambda_function {
      events = ["s3:ObjectCreated:*"]
      filter_prefix = "uploads/"
      filter_suffix = ".csv"
      lambda_function_arn = aws_lambda_function.processing_lambda_function.arn
    }
  }

  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_role" {
  name = "processing_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy for Lambda to access S3 and DynamoDB
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "lambda_s3_access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.processing_bucket.bucket}/*"
      },
      {
        Effect = "Allow"
        Action = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.dynamodb_table.arn
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "processing_lambda_function" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 15

  environment {
    variables = {
      DYNAMODB_NAME = var.dynamodb_name
    }
  }

  code {
    zip_file = <<ZIP_FILE
import boto3
import os

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ['DYNAMODB_NAME'])

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        obj = s3.get_object(Bucket=bucket, Key=key)
        metadata = obj['Metadata']

        table.put_item(Item={
            'ObjectKey': key,
            'Metadata': metadata
        })
ZIP_FILE
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.dynamodb_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "ObjectKey"
    type = "S"
  }

  hash_key = "ObjectKey"

  stream {
    stream_view_type = "NEW_IMAGE"
  }

  server_side_encryption {
    enabled = true
  }
}

# Lambda Permission for S3 to Invoke Lambda
resource "aws_lambda_permission" "lambda_s3_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processing_lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.processing_bucket.arn
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.processing_lambda_function.function_name}"
  retention_in_days = 14
}

output "s3_bucket_name" {
  value = aws_s3_bucket.processing_bucket.bucket
}

output "lambda_function_arn" {
  value = aws_lambda_function.processing_lambda_function.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.dynamodb_table.name
}
