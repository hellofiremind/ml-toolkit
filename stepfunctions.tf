locals {
  lambda_arn_prefix = "arn:aws:lambda:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:function"
}

# Template file for training step function definition
data "template_file" "training_template" {
  template = file("${path.cwd}/config/training-stepfunction.json")
  vars = {
    account_id         = data.aws_caller_identity.current.account_id
    region             = var.AWS_REGION
    service_name       = "${var.SERVICE}-${var.BUILD_STAGE}"
    sagemaker_role_arn = aws_iam_role.sagemaker_role.arn
  }
}

resource "aws_sfn_state_machine" "training_step_function" {
  name     = "${var.SERVICE}-${var.BUILD_STAGE}-training-step-function"
  role_arn = aws_iam_role.step_function_role.arn

  definition = data.template_file.training_template.rendered
}

# Template file for inference step function definition
data "template_file" "inference_template" {
  template = file("${path.cwd}/config/inference-stepfunction.json")
  vars = {
    account_id                   = data.aws_caller_identity.current.account_id
    region                       = var.AWS_REGION
    service_name                 = "${var.SERVICE}-${var.BUILD_STAGE}"
    sagemaker_role_arn           = aws_iam_role.sagemaker_role.arn
    check_endpoint_status_lambda = "${local.lambda_arn_prefix}:${aws_ssm_parameter.update_endpoint_status_lambda_name.value}"
  }
}

resource "aws_sfn_state_machine" "inference_step_function" {
  name     = "${var.SERVICE}-${var.BUILD_STAGE}-inference-step-function"
  role_arn = aws_iam_role.step_function_role.arn

  definition = data.template_file.inference_template.rendered
}
