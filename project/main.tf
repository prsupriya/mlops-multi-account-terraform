# main.tf

provider "aws" {
  region = var.aws_region
}

# S3 bucket for ML artifacts
resource "aws_s3_bucket" "mlops_artifacts_bucket" {
  bucket = "sagemaker-project-github-${var.sagemaker_project_id}-${var.aws_region}"
  
  tags = {
    "sagemaker:project-id"   = var.sagemaker_project_id
    "sagemaker:project-name" = var.sagemaker_project_name
  }
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "mlops_artifacts_bucket_versioning" {
  bucket = aws_s3_bucket.mlops_artifacts_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Lambda function to trigger GitHub workflows
resource "aws_lambda_function" "github_workflow_trigger_lambda" {
  description      = "To trigger the GitHub Workflow"
  function_name    = "sagemaker-${var.sagemaker_project_id}-github-trigger"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900
  role             = aws_iam_role.github_workflow_trigger_lambda_role.arn
  architectures    = ["arm64"]
  
  s3_bucket        = "swmlopslambdabucket"
  s3_key           = "lambda-github-workflow-trigger.zip"
  
  layers           = ["arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:layer:python39-github-arm64:1"]
  
  environment {
    variables = {
      DeployRepoName                  = var.code_repository_name
      GitHubWorkflowNameForDeployment = var.github_workflow_name_for_deployment
      GitHubTokenSecretName           = var.github_token_secret_name
      Region                          = var.aws_region
    }
  }
}

# IAM role for the Lambda function
resource "aws_iam_role" "github_workflow_trigger_lambda_role" {
  name        = "SageMakerGithubWorkflowTriggerLambdaExecutionRole-${substr(uuid(), 0, 8)}"
  description = "Lambda function to trigger GitHub workflow for deploying sagemaker model"
  
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
          Action = [
            "secretsmanager:GetSecretValue"
          ]
          Resource = [
            "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.github_token_secret_name}*"
          ]
        }
      ]
    })
  }
}

# EventBridge rule to trigger deployment when a model is approved
resource "aws_cloudwatch_event_rule" "model_deploy_sagemaker_event_rule" {
  name        = "sagemaker-${var.sagemaker_project_name}-${var.sagemaker_project_id}-event-rule"
  description = "Rule to trigger a deployment when SageMaker Model is Approved."
  
  event_pattern = jsonencode({
    source      = ["aws.sagemaker"]
    detail-type = ["SageMaker Model Package State Change"]
    detail      = {
      ModelPackageGroupName = ["${var.sagemaker_project_name}-${var.sagemaker_project_id}"]
      ModelApprovalStatus   = ["Approved"]
    }
  })
}

# Target for the EventBridge rule
resource "aws_cloudwatch_event_target" "model_deploy_lambda_target" {
  rule      = aws_cloudwatch_event_rule.model_deploy_sagemaker_event_rule.name
  target_id = "sagemaker-${var.sagemaker_project_name}-trigger"
  arn       = aws_lambda_function.github_workflow_trigger_lambda.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_lambda" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.github_workflow_trigger_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.model_deploy_sagemaker_event_rule.arn
}

# SageMaker code repository
resource "aws_sagemaker_code_repository" "sagemaker_code_repository" {
  code_repository_name = "${var.code_repository_name}-${var.sagemaker_project_id}"
  
  git_config {
    repository_url = "https://codestar-connections.${var.aws_region}.amazonaws.com/git-http/${var.aws_account_id}/${var.aws_region}/${var.codestar_connection_unique_id}/${var.github_repository_owner_name}/${var.code_repository_name}.git"
    branch         = "main"
  }
  
  tags = {
    "sagemaker:project-id"   = var.sagemaker_project_id
    "sagemaker:project-name" = var.sagemaker_project_name
  }
}

# Create SageMaker Model Package Group for the Model Registry
resource "aws_sagemaker_model_package_group" "model_package_group" {
  model_package_group_name        = "${var.sagemaker_project_name}-${var.sagemaker_project_id}"
  model_package_group_description = "Model package group for ${var.sagemaker_project_name}"
  
  tags = {
    "sagemaker:project-id"   = var.sagemaker_project_id
    "sagemaker:project-name" = var.sagemaker_project_name
  }
}
