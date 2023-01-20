# Codestar Connection
resource "aws_codestarconnections_connection" "github_connection" {
  name          = "github-connection"
  provider_type = "GitHub"
  lifecycle {
    ignore_changes = [
    ]
  }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = module.pipeline_artifact_bucket.s3_bucket_id
    type     = "S3"

    encryption_key {
      id   = aws_kms_alias.s3.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      run_order        = 1
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github_connection.arn
        FullRepositoryId = var.FULL_REPOSITORY_ID
        BranchName       = var.BRANCH
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "DeployTerraform"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["terraform_output"]
      version          = "1"
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.terraform_server.name
      }
    }

    action {
      name             = "DeployServerless"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["serverless_output"]
      version          = "1"
      run_order        = 2

      configuration = {
        ProjectName = aws_codebuild_project.serverless_server.name
      }
    }
  }
}


# CodeBuild Terraform
resource "aws_codebuild_project" "terraform_server" {
  name          = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-terraform-project"
  description   = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-terraform-project"
  build_timeout = "10"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("../buildspec-terraform.yml")

  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.AWS_REGION
    }

    environment_variable {
      name  = "SERVICE"
      value = var.SERVICE
    }

    environment_variable {
      name  = "BUILD_STAGE"
      value = var.BUILD_STAGE
    }

    environment_variable {
      name  = "SOURCE_BUCKET"
      value = "${var.SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-source-bucket"
    }

    environment_variable {
      name  = "TF_VERSION"
      value = "1.3.7"
    }
  }

  logs_config {
    s3_logs {
      status   = "ENABLED"
      location = "${module.pipeline_artifact_bucket.s3_bucket_id}/build-log"
    }
  }
}

# CodeBuild Serverless
resource "aws_codebuild_project" "serverless_server" {
  name          = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-serverless-project"
  description   = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-serverless-project"
  build_timeout = "10"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("../buildspec-serverless.yml")

  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.AWS_REGION
    }

    environment_variable {
      name  = "SERVICE"
      value = var.SERVICE
    }

    environment_variable {
      name  = "BUILD_STAGE"
      value = var.BUILD_STAGE
    }

    environment_variable {
      name  = "IAM_CODEBUILD_ROLE"
      value = aws_iam_role.codebuild_assume_role.arn
    }
  }

  logs_config {
    s3_logs {
      status   = "ENABLED"
      location = "${module.pipeline_artifact_bucket.s3_bucket_id}/build-log"
    }
  }
}

# CodeBuild IAM Role
resource "aws_iam_role" "codebuild_role" {
  name               = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust_relationship_policy.json
}

resource "aws_iam_policy" "codebuild_policy_attachment" {
  name        = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codebuild-policy"
  description = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codebuild-policy"
  policy      = data.aws_iam_policy_document.codebuild_policy_document.json
}

data "aws_iam_policy_document" "codebuild_trust_relationship_policy" {
  statement {
    sid = "AllowCodeBuild"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_policy_document" {
  statement {
    sid = "AllowAll"

    actions = [
      "*"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "codebuild_role_attachment" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy_attachment.arn
}

# CodeBuild Assume Role
resource "aws_iam_role" "codebuild_assume_role" {
  name               = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codebuild-assume-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_trust_relationship_policy.json
}

resource "aws_iam_policy" "codebuild_assume_policy_attachment" {
  name        = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codebuild-assume-policy"
  description = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codebuild-assume-policy"
  policy      = data.aws_iam_policy_document.codebuild_assume_policy_document.json
}

data "aws_iam_policy_document" "codebuild_assume_trust_relationship_policy" {
  statement {
    sid = "AllowCodeBuild"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.codebuild_role.arn]
    }
  }
}

data "aws_iam_policy_document" "codebuild_assume_policy_document" {
  statement {
    sid = "S3"

    actions = [
      "s3:Get*",
      "s3:Put*",
      "s3:List*"
    ]

    resources = [
      "arn:aws:s3:::${var.SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-serverless-bucket",
      "arn:aws:s3:::${var.SERVICE}-${var.BUILD_STAGE}-${data.aws_caller_identity.current.account_id}-serverless-bucket/*",
    ]
  }

  statement {
    sid = "KMSDecrypt"

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid     = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:TagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "Ssm"
    actions = [
      "ssm:*"
    ]
    resources = [
      "arn:aws:ssm:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:parameter/*"
    ]
  }

  statement {
    sid     = "Cloudformation"
    actions = [
      "cloudformation:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid     = "Lambda"
    actions = [
      "lambda:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid     = "IamPassRole"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "codebuild_assume_role_attachment" {
  role       = aws_iam_role.codebuild_assume_role.name
  policy_arn = aws_iam_policy.codebuild_assume_policy_attachment.arn
}

# CODEPIPELINE IAM ROLE
resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-pipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_trust_relationship_policy.json
}

resource "aws_iam_policy" "codepipeline_policy_attachment" {
  name        = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codepipeline-policy"
  description = "${var.CICD_SERVICE}-${var.BUILD_STAGE}-codepipeline-policy"
  policy      = data.aws_iam_policy_document.codepipeline_policy_document.json
}

data "aws_iam_policy_document" "codepipeline_trust_relationship_policy" {
  statement {
    sid = "AllowCodePipeline"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline_policy_document" {
  statement {
    sid       = "AllowAll"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "codepipeline_role_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy_attachment.arn
}