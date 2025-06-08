# variables.tf

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "sagemaker_project_name" {
  description = "Name of the SageMaker project"
  type        = string
  validation {
    condition     = length(var.sagemaker_project_name) >= 1 && length(var.sagemaker_project_name) <= 32 && can(regex("^[a-zA-Z](-*[a-zA-Z0-9])*", var.sagemaker_project_name))
    error_message = "Project name must be 1-32 characters and start with a letter, followed by letters, numbers, or hyphens."
  }
}

variable "sagemaker_project_id" {
  description = "Service generated ID of the project"
  type        = string
}

variable "code_repository_name" {
  description = "Repository name of the Model Building, Training and Deployment in GitHub"
  type        = string
  validation {
    condition     = length(var.code_repository_name) <= 1024
    error_message = "Repository name must be at most 1024 characters."
  }
}

variable "github_repository_owner_name" {
  description = "GitHub Repository Owner Name"
  type        = string
  validation {
    condition     = length(var.github_repository_owner_name) <= 1024
    error_message = "GitHub repository owner name must be at most 1024 characters."
  }
}

variable "codestar_connection_unique_id" {
  description = "Codestar connection unique identifier"
  type        = string
  validation {
    condition     = length(var.codestar_connection_unique_id) <= 1024
    error_message = "Codestar connection ID must be at most 1024 characters."
  }
}

variable "github_token_secret_name" {
  description = "Name of GitHub Token in AWS Secret Manager. This is to call deploy github workflow."
  type        = string
  validation {
    condition     = length(var.github_token_secret_name) <= 1024
    error_message = "GitHub token secret name must be at most 1024 characters."
  }
}

variable "github_workflow_name_for_deployment" {
  description = "GitHub workflow file name which runs the deployment steps."
  type        = string
  validation {
    condition     = length(var.github_workflow_name_for_deployment) <= 1024
    error_message = "GitHub workflow name must be at most 1024 characters."
  }
}
