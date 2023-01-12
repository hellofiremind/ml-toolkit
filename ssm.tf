resource "aws_ssm_parameter" "source_bucket" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/source_bucket"
  type  = "String"
  value = module.source_bucket.s3_bucket_id
}

resource "aws_ssm_parameter" "ml_pipeline_bucket" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/ml_pipeline_bucket"
  type  = "String"
  value = module.machine_learning_pipeline_bucket.s3_bucket_id
}

resource "aws_ssm_parameter" "codepipeline_artifact_bucket" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/codepipeline_artifact_bucket"
  type  = "String"
  value = module.pipeline_artifact_bucket.s3_bucket_id
}

resource "aws_ssm_parameter" "serverless_bucket" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/serverless_bucket"
  type  = "String"
  value = module.serverless_bucket.s3_bucket_id
}

resource "aws_ssm_parameter" "create_schema_lambda_name" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/create_schema_lambda_name"
  type  = "String"
  value = "${var.SERVICE}-${var.BUILD_STAGE}-create-schema-lambda"
}

resource "aws_ssm_parameter" "update_schema_lambda_name" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/update_schema_lambda_name"
  type  = "String"
  value = "${var.SERVICE}-${var.BUILD_STAGE}-update-schema-lambda"
}

resource "aws_ssm_parameter" "update_endpoint_status_lambda_name" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/update_endpoint_status_lambda_name"
  type  = "String"
  value = "${var.SERVICE}-${var.BUILD_STAGE}-update-endpoint-status-lambda"
}

resource "aws_ssm_parameter" "lambda_iam_role" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/lambda_iam_role"
  type  = "String"
  value = aws_iam_role.lambda_role.arn
}

resource "aws_ssm_parameter" "kms_key" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/kms_key"
  type  = "String"
  value = aws_kms_key.deployment_key.id
}

resource "aws_ssm_parameter" "training_step_function_arn" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/training_step_function_arn"
  type  = "String"
  value = aws_sfn_state_machine.training_step_function.arn
}

resource "aws_ssm_parameter" "inference_step_function_arn" {
  name  = "/${var.SERVICE}/${var.BUILD_STAGE}/inference_step_function_arn"
  type  = "String"
  value = aws_sfn_state_machine.inference_step_function.arn
}