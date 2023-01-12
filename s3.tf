# Source bucket which holds manifest, source python files etc
module "source_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-source-bucket"
  acl    = "private"

  versioning = {
    enabled = true
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy           = true
}

# Workflow bucket which holds all the inputs and outputs from the execution of the pipeline
module "machine_learning_pipeline_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-workflow-bucket"
  acl    = "private"

  versioning = {
    enabled = false
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy           = true
}

# CodePipeline bucket which holds input/output artifacts
module "pipeline_artifact_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-artifact-bucket"
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
        kms_master_key_id = aws_kms_alias.deployment_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  force_destroy = true
}

# Serverless bucket used by serverless for Lambda deployment
module "serverless_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-serverless-bucket"
  acl    = "private"

  versioning = {
    enabled = false
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy           = true
}