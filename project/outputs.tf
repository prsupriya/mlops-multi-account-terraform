# outputs.tf

output "mlops_artifacts_bucket" {
  description = "S3 bucket for ML artifacts"
  value       = aws_s3_bucket.mlops_artifacts_bucket.id
}

output "github_workflow_trigger_lambda" {
  description = "Lambda function ARN for triggering GitHub workflows"
  value       = aws_lambda_function.github_workflow_trigger_lambda.arn
}

output "sagemaker_code_repository_name" {
  description = "SageMaker code repository name"
  value       = aws_sagemaker_code_repository.sagemaker_code_repository.code_repository_name
}

output "model_package_group_name" {
  description = "SageMaker Model Package Group name"
  value       = aws_sagemaker_model_package_group.model_package_group.model_package_group_name
}

output "event_rule_arn" {
  description = "EventBridge rule ARN for model deployment"
  value       = aws_cloudwatch_event_rule.model_deploy_sagemaker_event_rule.arn
}
