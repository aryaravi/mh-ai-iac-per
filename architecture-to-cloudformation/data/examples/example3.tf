provider "aws" {
  region = "us-west-2"
}

resource "aws_lambda_function" "clean_data" {
  function_name = "InvokeCleanData"
  handler       = "clean_data.handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec.arn
  source_code_hash = filebase64sha256("path/to/clean_data.zip")
  filename         = "path/to/clean_data.zip"
}

resource "aws_lambda_function" "summarize_data" {
  function_name = "InvokeSummarizeData"
  handler       = "summarize_data.handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec.arn
  source_code_hash = filebase64sha256("path/to/summarize_data.zip")
  filename         = "path/to/summarize_data.zip"
}

resource "aws_lambda_function" "action_item_data" {
  function_name = "InvokeActionItemData"
  handler       = "action_item_data.handler"
  runtime       = "python3.8"
  role          = aws_iam_role.lambda_exec.arn
  source_code_hash = filebase64sha256("path/to/action_item_data.zip")
  filename         = "path/to/action_item_data.zip"
}

resource "aws_s3_bucket" "processed_data" {
  bucket = "aurogou-s3"
}

resource "aws_sagemaker_notebook_instance" "sagemaker_instance" {
  name                 = "AurogouSG"
  instance_type        = "ml.t2.medium"
  role_arn             = aws_iam_role.sagemaker_exec.arn
  lifecycle_config_name = aws_sagemaker_notebook_instance_lifecycle_configuration.sagemaker_lifecycle.name
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "sagemaker_exec" {
  name = "sagemaker_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "sagemaker_lifecycle" {
  name = "sagemaker_lifecycle_config"

  on_create = <<EOF
#!/bin/bash
set -e
# Add your lifecycle configuration script here
EOF
}
