# SAGEMAKER ROLE
data "aws_iam_policy_document" "sagemaker_role_policy" {
  statement {
    sid = "S3"
    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      module.machine_learning_pipeline_bucket.s3_bucket_arn,
      "${module.machine_learning_pipeline_bucket.s3_bucket_arn}/*",
      module.source_bucket.s3_bucket_arn,
      "${module.source_bucket.s3_bucket_arn}/*"

    ]
  }

  statement {
    sid = "ECR"
    actions = [
      "ecr:*"
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudwatchLogs"
    actions = [
      "logs:*"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid = "Cloudwatch"
    actions = [
      "cloudwatch:*",
      "events:*"
    ]
    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "sagemaker_trust_relationship_policy" {
  statement {
    sid = "AllowSagemaker"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sagemaker_role" {
  name               = "${var.SERVICE}-${var.BUILD_STAGE}-sagemaker-role"
  assume_role_policy = data.aws_iam_policy_document.sagemaker_trust_relationship_policy.json
}

resource "aws_iam_policy" "sagemaker_policy_attachment" {
  name        = "${var.SERVICE}-${var.BUILD_STAGE}-sagemaker-policy"
  description = "${var.SERVICE}-${var.BUILD_STAGE}-sagemaker-policy"
  policy      = data.aws_iam_policy_document.sagemaker_role_policy.json
}

resource "aws_iam_role_policy_attachment" "sagemaker_role_attachment" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = aws_iam_policy.sagemaker_policy_attachment.arn
}

# STEP FUNCTION ROLE
resource "aws_iam_role" "step_function_role" {
  name               = "${var.SERVICE}-${var.BUILD_STAGE}-step-function-role"
  assume_role_policy = data.aws_iam_policy_document.step_function_trust_relationship_policy.json
}

resource "aws_iam_role_policy_attachment" "step_function_role_attachment" {
  role       = aws_iam_role.step_function_role.name
  policy_arn = aws_iam_policy.step_function_policy.arn
}

data "aws_iam_policy_document" "step_function_trust_relationship_policy" {
  statement {
    sid = "AllowStepFunction"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "step_function_role_policy_attachment" {

  statement {
    sid = "IAM"

    actions = [
      "iam:PassRole"
    ]

    resources = ["*"]
  }

  statement {
    sid = "CloudwatchLogs"

    actions = [
      "events:*",
      "logs:*"
    ]

    resources = ["*"]
  }

  statement {
    sid = "S3"

    actions = [
      "s3:*"
    ]

    resources = [
      module.pipeline_artifact_bucket.s3_bucket_arn,
      "${module.pipeline_artifact_bucket.s3_bucket_arn}/*"
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
    sid = "SageMaker"

    actions = [
      "sagemaker:CreateProcessingJob",
      "sagemaker:CreateTrainingJob",
      "sagemaker:CreateTransformJob",
      "sagemaker:CreateModel",
      "sagemaker:CreateEndpointConfig",
      "sagemaker:CreateEndpoint",
      "sagemaker:DescribeEndpoint",
      "sagemaker:AddTags"
    ]
    resources = [
      "arn:aws:sagemaker:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:processing-job/*",
      "arn:aws:sagemaker:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:training-job/*",
      "arn:aws:sagemaker:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:model/*",
      "arn:aws:sagemaker:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:transform-job/*",
      "arn:aws:sagemaker:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:endpoint/*",
      "arn:aws:sagemaker:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:endpoint-config/*"
    ]
  }

  statement {
    sid = "Lambda"

    actions = [
      "lambda:InvokeFunction"
    ]

    resources = [
      "${local.lambda_arn_prefix}:${aws_ssm_parameter.update_endpoint_status_lambda_name.value}"
    ]
  }
}

resource "aws_iam_policy" "step_function_policy" {
  name        = "${var.SERVICE}-${var.BUILD_STAGE}-step-function-policy"
  description = "${var.SERVICE}-${var.BUILD_STAGE}-step-function-policy"
  policy      = data.aws_iam_policy_document.step_function_role_policy_attachment.json
}

# LAMBDA FUNCTION ROLE
resource "aws_iam_role" "lambda_role" {
  name               = "${var.SERVICE}-${var.BUILD_STAGE}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust_relationship_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

data "aws_iam_policy_document" "lambda_trust_relationship_policy" {
  statement {
    sid = "AllowLambda"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_role_policy_attachment" {

  statement {
    sid = "IAM"

    actions = [
      "iam:PassRole"
    ]

    resources = ["*"]
  }

  statement {
    sid = "CodePipeline"
    actions = [
      "codepipeline:PutJobFailureResult",
      "codepipeline:PutJobSuccessResult",
      "codepipeline:PutApprovalResult"
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudwatchLogs"

    actions = [
      "events:*",
      "logs:*"
    ]

    resources = ["*"]
  }

  statement {
    sid = "S3"

    actions = [
      "s3:*"
    ]

    resources = [
      module.pipeline_artifact_bucket.s3_bucket_arn,
      "${module.pipeline_artifact_bucket.s3_bucket_arn}/*",
      module.machine_learning_pipeline_bucket.s3_bucket_arn,
      "${module.machine_learning_pipeline_bucket.s3_bucket_arn}/*",
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
    sid = "EC2"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface"
    ]
    resources = ["*"]
  }

  statement {
    sid = "SSM"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:aws:ssm:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    sid = "SageMaker"

    actions = [
      "sagemaker:DescribeEndpoint"
    ]

    resources = [
      "arn:aws:sagemaker:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:endpoint/*",
    ]
  }


}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.SERVICE}-${var.BUILD_STAGE}-lambda-policy"
  description = "${var.SERVICE}-${var.BUILD_STAGE}-lambda-policy"
  policy      = data.aws_iam_policy_document.lambda_role_policy_attachment.json
}

# CODEPIPELINE IAM ROLE
resource "aws_iam_role" "codepipeline_role" {
  name               = "${var.SERVICE}-${var.BUILD_STAGE}-pipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_trust_relationship_policy.json
}

resource "aws_iam_policy" "codepipeline_policy_attachment" {
  name        = "${var.SERVICE}-${var.BUILD_STAGE}-codepipeline-policy"
  description = "${var.SERVICE}-${var.BUILD_STAGE}-codepipeline-policy"
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
    sid = "S3"

    actions = [
      "s3:Get*",
      "s3:Put*",
      "s3:List*"
    ]

    resources = [
      module.pipeline_artifact_bucket.s3_bucket_arn,
      "${module.pipeline_artifact_bucket.s3_bucket_arn}/*",
      module.source_bucket.s3_bucket_arn,
      "${module.source_bucket.s3_bucket_arn}/*",
      module.machine_learning_pipeline_bucket.s3_bucket_arn,
      "${module.machine_learning_pipeline_bucket.s3_bucket_arn}/*"
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
    sid = "All"

    actions = [
      "*"
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "codepipeline_role_attachment" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy_attachment.arn
}