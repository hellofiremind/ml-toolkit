# Template file for step function definition
data "template_file" "json_template" {
  template = file("${path.cwd}/config/stepfunction.json")
  vars = {
    account_id         = data.aws_caller_identity.current.account_id
    region             = var.AWS_REGION
    service_name       = "${var.SERVICE}-${var.BUILD_STAGE}"
    sagemaker_role_arn = aws_iam_role.sagemaker_role.arn
  }
}

resource "aws_sfn_state_machine" "step_function" {
  name     = "${var.SERVICE}-${var.BUILD_STAGE}-step-function"
  role_arn = aws_iam_role.step_function_role.arn

  definition = data.template_file.json_template.rendered
}
