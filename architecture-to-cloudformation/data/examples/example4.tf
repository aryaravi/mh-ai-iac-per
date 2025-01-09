provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "CodePipelineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "CodePipelinePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:ListImages",
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:BatchGetProjects",
          "s3:*"
        ]
        Resource = "*"
      }]
    })
  }
}

resource "aws_iam_role" "codebuild_role" {
  name = "CodeBuildRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "CodeBuildPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:ListImages",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }]
    })
  }
}

resource "aws_s3_bucket" "pipeline_artifact_bucket" {
  bucket = "pipeline-artifact-bucket"
  versioning {
    enabled = true
  }
}

resource "aws_codebuild_project" "codebuild_project" {
  name          = "BuildDockerImage"
  service_role  = aws_iam_role.codebuild_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    environment_variable {
      name  = "BASE_IMAGE_URI"
      value = var.ecr_base_image_uri
    }
    environment_variable {
      name  = "TARGET_REPO_URI"
      value = var.ecr_target_repo_uri
    }
  }
  source {
    type = "CODEPIPELINE"
  }
  timeout_in_minutes = 60
  cache {
    type = "NO_CACHE"
  }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "CodePipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline_artifact_bucket.bucket
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceOutput"]
      configuration = {
        S3Bucket            = var.source_code_bucket_name
        S3ObjectKey         = var.source_code_file_name
        PollForSourceChanges = "false"
      }
    }
  }
  stage {
    name = "Build"
    action {
      name             = "BuildAction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildArtifact"]
      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project.name
      }
    }
  }
}

variable "ecr_base_image_uri" {
  type        = string
  default     = "334189989353.dkr.ecr.us-east-1.amazonaws.com/baseimage"
  description = "URI of the base image in ECR"
}

variable "source_code_bucket_name" {
  type        = string
  default     = "app-war-bucket"
  description = "Name of the S3 bucket where the source code is stored"
}

variable "source_code_file_name" {
  type        = string
  default     = "code.zip"
  description = "Name of the source code object inside the S3 bucket"
}

variable "ecr_target_repo_uri" {
  type        = string
  default     = "334189989353.dkr.ecr.us-east-1.amazonaws.com/appimage"
  description = "URI of the target ECR repository"
}