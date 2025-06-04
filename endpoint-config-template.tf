# Description block converted to comments
# This template is built and deployed by the infrastructure pipeline in various stages (staging/production) as required.
# It specifies the resources that need to be created, like the SageMaker Endpoint. It can be extended to include resources like
# AutoScalingPolicy, API Gateway, etc,. as required.

# Variables (equivalent to CloudFormation Parameters)
variable "SageMakerProjectName" {
  type        = string
  description = "Name of the project"
  validation {
    condition     = can(regex("^[a-zA-Z](-*[a-zA-Z0-9])*$", var.SageMakerProjectName)) && length(var.SageMakerProjectName) >= 1 && length(var.SageMakerProjectName) <= 32
    error_message = "SageMakerProjectName must match pattern ^[a-zA-Z](-*[a-zA-Z0-9])* and be between 1-32 characters."
  }
}

variable "ModelExecutionRoleArn" {
  type        = string
  description = "Execution role used for deploying the model."
}

variable "ModelPackageName" {
  type        = string
  description = "The trained Model Package Name"
}

variable "StageName" {
  type        = string
  description = "The name for a project pipeline stage, such as Staging or Prod, for which resources are provisioned and deployed."
}

variable "EndpointInstanceCount" {
  type        = number
  description = "Number of instances to launch for the endpoint."
  validation {
    condition     = var.EndpointInstanceCount >= 1
    error_message = "EndpointInstanceCount must be at least 1."
  }
}

variable "EndpointInstanceType" {
  type        = string
  description = "The ML compute instance type for the endpoint."
}

# Resources
resource "aws_sagemaker_model" "model" {
  name               = "${var.SageMakerProjectName}-model"
  execution_role_arn = var.ModelExecutionRoleArn

  container {
    model_package_name = var.ModelPackageName
  }
}

resource "aws_sagemaker_endpoint_configuration" "endpoint_config" {
  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.model.name
    initial_instance_count = var.EndpointInstanceCount
    initial_variant_weight = 1.0
    instance_type          = var.EndpointInstanceType
  }
}

resource "aws_sagemaker_endpoint" "endpoint" {
  name                 = "${var.SageMakerProjectName}-${var.StageName}"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.endpoint_config.name
}