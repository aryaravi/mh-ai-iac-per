provider "aws" {
  region = "us-west-2"  # Set to your desired region
}

# Variables
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "DataProcessingTable"
}

# DynamoDB Table with encryption at rest
resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"
  }

  hash_key = "id"

  stream {
    stream_view_type = "NEW_AND_OLD_IMAGES"
  }

  server_side_encryption {
    enabled = true  # Encryption at rest enabled
    sse_algorithm = "AES256"  # Specifying AES256 encryption algorithm
  }

  tags = {
    Compliance = "FedRAMP"
  }
}

# DynamoDB Stream (Event Source for Lambda)
resource "aws_lambda_event_source_mapping" "dynamodb_stream" {
  event_source_arn = aws_dynamodb_table.dynamodb_table.stream_arn
  function_name    = aws_lambda_function.processing_lambda_function.arn
  starting_position = "LATEST"
  batch_size       = 1
}

# Lambda Function for Processing DynamoDB Stream
resource "aws_lambda_function" "processing_lambda_function" {
  function_name = "LogFunction"
  runtime       = "python3.12"
  handler       = "index.lambda_handler"
  role          = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
    }
  }

  code {
    zip_file = <<ZIP_FILE
import json
import boto3

def lambda_handler(event, context):
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('DataProcessingTable')

    for record in event['Records']:
        if record['eventName'] == 'INSERT':
            new_item = record['dynamodb']['NewImage']
            item_id = new_item['id']['S']
            # Process the new item
            print(f"New item inserted: {item_id}")
        elif record['eventName'] == 'MODIFY':
            new_item = record['dynamodb']['NewImage']
            old_item = record['dynamodb']['OldImage']
            item_id = new_item['id']['S']
            # Process the modified item
            print(f"Item modified: {item_id}")

    return {
        'statusCode': 200,
        'body': json.dumps('Data processing completed successfully')
    }
ZIP_FILE
  }

  tags = {
    Compliance = "FedRAMP"
  }
}

# IAM Role for Lambda Function with least privilege access
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

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

# Attach IAM policy to Lambda Role to allow access to DynamoDB stream
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.dynamodb_table.stream_arn
      }
    ]
  })
}

# CloudWatch Log Group for Lambda with FedRAMP compliant retention
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.processing_lambda_function.function_name}"
  retention_in_days = 90  # FedRAMP requires 90 days log retention
  tags = {
    Compliance = "FedRAMP"
  }
}

# Lambda Permission for DynamoDB to trigger Lambda
resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processing_lambda_function.function_name
  principal     = "dynamodb.amazonaws.com"
  source_arn    = aws_dynamodb_table.dynamodb_table.stream_arn
}

# Outputs
output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.dynamodb_table.name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = aws_lambda_function.processing_lambda_function.arn
}
