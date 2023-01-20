# CodePipeline bucket which holds input/output artifacts
module "pipeline_artifact_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-artifact-bucket"
  acl    = "private"

  versioning = {
    enabled = false
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_alias.s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  force_destroy = true
}