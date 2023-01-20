resource "aws_kms_key" "s3" {
  description             = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.CICD_SERVICE}-${var.BUILD_STAGE}-key"
  target_key_id = aws_kms_key.s3.key_id
}