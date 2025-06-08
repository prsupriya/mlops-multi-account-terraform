# Variables definition
variable "SageMakerProjectName" {
  description = "Name of the project"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z](-*[a-zA-Z0-9])*$", var.SageMakerProjectName)) && length(var.SageMakerProjectName) >= 1 && length(var.SageMakerProjectName) <= 32
    error_message = "SageMakerProjectName must match pattern ^[a-zA-Z](-*[a-zA-Z0-9])* and be between 1-32 characters."
  }
  sensitive = true
}

variable "SageMakerProjectId" {
  description = "Service generated ID of the project."
  type        = string
  sensitive   = true
}

variable "CodeRepositoryName" {
  description = "Repository name of the Model Building, Training and Deployment in GitHub"
  type        = string
  validation {
    condition     = length(var.CodeRepositoryName) <= 1024
    error_message = "CodeRepositoryName must be at most 1024 characters."
  }
}

variable "GitHubRepositoryOwnerName" {
  description = "GitHub Repository Owner Name"
  type        = string
  validation {
    condition     = length(var.GitHubRepositoryOwnerName) <= 1024
    error_message = "GitHubRepositoryOwnerName must be at most 1024 characters."
  }
}

variable "CodestarConnectionUniqueId" {
  description = "Codestar connection unique identifier"
  type        = string
  validation {
    condition     = length(var.CodestarConnectionUniqueId) <= 1024
    error_message = "CodestarConnectionUniqueId must be at most 1024 characters."
  }
}

variable "GitHubTokenSecretName" {
  description = "Name of GitHub Token in AWS Secret Manager. This is to call deploy github workflow."
  type        = string
  validation {
    condition     = length(var.GitHubTokenSecretName) <= 1024
    error_message = "GitHubTokenSecretName must be at most 1024 characters."
  }
}

variable "GitHubWorkflowNameForDeployment" {
  description = "GitHub workflow file name which runs the deployment steps."
  type        = string
  validation {
    condition     = length(var.GitHubWorkflowNameForDeployment) <= 1024
    error_message = "GitHubWorkflowNameForDeployment must be at most 1024 characters."
  }
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Random string for role name suffix (to replace the CloudFormation stack ID reference)
resource "random_string" "role_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket
resource "aws_s3_bucket" "MlOpsArtifactsBucket" {
  bucket = "sagemaker-project-github-${var.SageMakerProjectId}-${data.aws_region.current.name}"
}

# IAM Role for Lambda
resource "aws_iam_role" "GitHubWorkflowTriggerLambdaExecutionRole" {
  name        = "SageMakerGithubWorkflowTriggerLambdaExecutionRole-${random_string.role_suffix.result}"
  description = "lambda function to trigger GitHub workflow for deploying sagemaker model"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"]

  inline_policy {
    name = "GitHubWorkflowTriggerExecutionPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["secretsmanager:GetSecretValue"]
          Resource = ["arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.GitHubTokenSecretName}*"]
        }
      ]
    })
  }
}

# Lambda Function
resource "aws_lambda_function" "GitHubWorkflowTriggerLambda" {
  description      = "To trigger the GitHub Workflow"
  function_name    = "sagemaker-${var.SageMakerProjectId}-github-trigger"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900
  role             = aws_iam_role.GitHubWorkflowTriggerLambdaExecutionRole.arn
  architectures    = ["arm64"]
  
  s3_bucket        = "swmlopslambdabucket"
  s3_key           = "lambda-github-workflow-trigger.zip"
  
  layers           = ["arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:python39-github-arm64:1"]
  
  environment {
    variables = {
      DeployRepoName                  = var.CodeRepositoryName
      GitHubWorkflowNameForDeployment = var.GitHubWorkflowNameForDeployment
      GitHubTokenSecretName           = var.GitHubTokenSecretName
      Region                          = data.aws_region.current.name
    }
  }
}

# EventBridge Rule
resource "aws_cloudwatch_event_rule" "ModelDeploySageMakerEventRule" {
  name        = "sagemaker-${var.SageMakerProjectName}-${var.SageMakerProjectId}-event-rule"
  description = "Rule to trigger a deployment when SageMaker Model is Approved."
  
  event_pattern = jsonencode({
    source      = ["aws.sagemaker"]
    detail-type = ["SageMaker Model Package State Change"]
    detail      = {
      ModelPackageGroupName = ["${var.SageMakerProjectName}-${var.SageMakerProjectId}"]
      ModelApprovalStatus   = ["Approved"]
    }
  })
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ModelDeploySageMakerEventRule.name
  target_id = "sagemaker-${var.SageMakerProjectName}-trigger"
  arn       = aws_lambda_function.GitHubWorkflowTriggerLambda.arn
}

# Lambda Permission
resource "aws_lambda_permission" "PermissionForEventsToInvokeLambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.GitHubWorkflowTriggerLambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ModelDeploySageMakerEventRule.arn
}

# SageMaker Code Repository
resource "aws_sagemaker_code_repository" "SagemakerCodeRepository" {
  code_repository_name = "${var.CodeRepositoryName}-${var.SageMakerProjectId}"
  
  git_config {
    repository_url = "https://codestar-connections.${data.aws_region.current.name}.amazonaws.com/git-http/${data.aws_caller_identity.current.account_id}/${data.aws_region.current.name}/${var.CodestarConnectionUniqueId}/${var.GitHubRepositoryOwnerName}/${var.CodeRepositoryName}.git"
    branch         = "main"
  }
  
  tags = {
    "sagemaker:project-id"   = var.SageMakerProjectId
    "sagemaker:project-name" = var.SageMakerProjectName
  }
}
