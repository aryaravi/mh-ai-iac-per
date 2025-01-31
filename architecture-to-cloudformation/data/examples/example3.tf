provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "logging_bucket" {
  bucket = "my-logging-bucket"
  versioning {
    enabled = true
  }
  logging {
    target_bucket = aws_s3_bucket.logging_bucket.id
    target_prefix = "logging/"
  }
  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"  # Enabling SSE-S3 encryption.
      }
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_object" "logging_bucket_policy" {
  bucket = aws_s3_bucket.logging_bucket.id
  key    = "logging-policy"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:PutObject"]
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Resource = "${aws_s3_bucket.logging_bucket.arn}/*"
      },
      {
        Action = ["s3:*"]
        Effect = "Deny"
        Resource = [
          "${aws_s3_bucket.logging_bucket.arn}/*",
          aws_s3_bucket.logging_bucket.arn
        ]
        Principal = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "origin_bucket" {
  bucket = "my-origin-bucket"
  versioning {
    enabled = true
  }
  logging {
    target_bucket = aws_s3_bucket.logging_bucket.id
    target_prefix = "origin-logs/"
  }
  notification {
    eventbridge {
      eventbridge_enabled = true
    }
  }
  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"  # Enabling SSE-S3 encryption.
      }
    }
  }
}

resource "aws_s3_bucket_object" "origin_bucket_policy" {
  bucket = aws_s3_bucket.origin_bucket.id
  key    = "origin-policy"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:*"]
        Effect = "Deny"
        Resource = [
          "${aws_s3_bucket.origin_bucket.arn}/*",
          aws_s3_bucket.origin_bucket.arn
        ]
        Principal = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "delivery_bucket" {
  bucket = "my-delivery-bucket"
  versioning {
    enabled = true
  }
  logging {
    target_bucket = aws_s3_bucket.logging_bucket.id
    target_prefix = "delivery-logs/"
  }
  public_access_block_configuration {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"  # Enabling SSE-S3 encryption.
      }
    }
  }
}

resource "aws_s3_bucket_object" "delivery_bucket_policy" {
  bucket = aws_s3_bucket.delivery_bucket.id
  key    = "delivery-policy"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:*"]
        Effect = "Deny"
        Resource = [
          "${aws_s3_bucket.delivery_bucket.arn}/*",
          aws_s3_bucket.delivery_bucket.arn
        ]
        Principal = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "CloudWatchLogsPolicy"
  description = "CloudWatch Logs policy for Lambda functions"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_invoke_policy" {
  name        = "BedrockInvokePolicy"
  description = "Allow invocation of Bedrock models"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/anthropic.claude-v2"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "LambdaExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sts:AssumeRole"
      }
    ]
  })

  policy {
    name = "LambdaExecutionPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = [
            "${aws_s3_bucket.origin_bucket.arn}/*",
            "${aws_s3_bucket.delivery_bucket.arn}/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "lambda:InvokeFunction"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:*:*:*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "clean_function" {
  function_name = "CleanFunction"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"
  timeout       = 900

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  code {
    zip_file = <<ZIP
import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    s3_key = event["detail"]["object"]["key"]
    bucket_name = event["detail"]["bucket"]["name"]

    s3_response = s3.get_object(Bucket=bucket_name, Key=s3_key)
    data = s3_response['Body'].read().decode('utf-8')

    return {
        "clean_data": data,
    }
ZIP
  }
}

resource "aws_iam_role" "state_machine_role" {
  name = "StateMachineRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action   = "sts:AssumeRole"
      }
    ]
  })
  policy {
    name = "StateMachineInvokeLambdaPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["lambda:InvokeFunction"]
          Resource = [
            aws_lambda_function.clean_function.arn,
            aws_lambda_function.summarize_function.arn,
            aws_lambda_function.action_item_function.arn
          ]
        }
      ]
    })
  }
}

resource "aws_stepfunctions_state_machine" "data_processing_state_machine" {
  name     = "DataProcessingStateMachine"
  role_arn = aws_iam_role.state_machine_role.arn

  definition = <<STATE_MACHINE
{
  "StartAt": "CleanData",
  "States": {
    "CleanData": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "${aws_lambda_function.clean_function.arn}"
      },
      "Next": "Parallel"
    },
    "Parallel": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "SummarizeData",
          "States": {
            "SummarizeData": {
              "Type": "Task",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${aws_lambda_function.summarize_function.arn}"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "ActionItemData",
          "States": {
            "ActionItemData": {
              "Type": "Task",
              "Resource": "arn:aws:states:::lambda:invoke",
              "Parameters": {
                "Payload.$": "$",
                "FunctionName": "${aws_lambda_function.action_item_function.arn}"
              },
              "End": true
            }
          }
        }
      ],
      "End": true
    }
  }
}
STATE_MACHINE
}
