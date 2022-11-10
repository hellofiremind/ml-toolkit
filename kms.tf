resource "aws_kms_key" "deployment_key" {
  description             = "${var.SERVICE}-${var.BUILD_STAGE}-key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "deployment_key" {
  name          = "alias/${var.SERVICE}-${var.BUILD_STAGE}-key"
  target_key_id = aws_kms_key.deployment_key.key_id
}