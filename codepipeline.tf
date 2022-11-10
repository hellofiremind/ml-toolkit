resource "aws_codepipeline" "codepipeline" {
  name     = "${var.SERVICE}-${var.BUILD_STAGE}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = module.pipeline_artifact_bucket.s3_bucket_id
    type     = "S3"

    encryption_key {
      id   = aws_kms_alias.deployment_key.arn
      type = "KMS"
    }
  }

  stage {
    name = "UploadManifest"

    action {
      name             = "UploadManifest"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      run_order        = 1
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket             = module.source_bucket.s3_bucket_id
        S3ObjectKey          = "config/manifest.json"
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "MachineLearningStage"

    action {
      name             = "InvokeCreateSchemaFunction"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "Lambda"
      input_artifacts  = ["source_output"]
      output_artifacts = ["create_schema_output"]
      version          = "1"
      run_order        = 1

      configuration = {
        FunctionName = aws_ssm_parameter.create_schema_lambda_name.value
      }
    }

    action {
      name      = "UploadSourceData"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
      run_order = 2

      configuration = {
        CustomData = "Please upload source data to begin ML workflow."
      }
    }

    action {
      name             = "InvokeMLStepFunction"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "StepFunctions"
      input_artifacts  = ["create_schema_output"]
      output_artifacts = ["ml_step_function_output"]
      version          = "1"
      run_order        = 3

      configuration = {
        StateMachineArn = aws_sfn_state_machine.step_function.arn
        InputType       = "FilePath"
        Input           = "manifest.json"
      }
    }
  }

  stage {
    name = "ApproveModelStage"

    action {
      name     = "ApprovalMLModel"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        CustomData = "Please approve model to continue workflow."
      }
    }
  }

  stage {
    name = "InferenceStage"

    action {
      name             = "InvokeUpdateSchemaFunction"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "Lambda"
      input_artifacts  = ["ml_step_function_output"]
      output_artifacts = ["update_schema_output"]
      version          = "1"
      run_order        = 1

      configuration = {
        FunctionName = aws_ssm_parameter.update_schema_lambda_name.value
      }
    }

    action {
      name      = "UploadInferenceDataConfirmation"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
      run_order = 2

      configuration = {
        CustomData = "Please upload inference data to begin inference."
      }
    }

    action {
      name             = "InvokeMLStepFunctionBatch"
      category         = "Invoke"
      owner            = "AWS"
      provider         = "StepFunctions"
      input_artifacts  = ["update_schema_output"]
      output_artifacts = ["ml_step_function_batch_output"]
      version          = "1"
      run_order        = 3

      configuration = {
        StateMachineArn = aws_sfn_state_machine.step_function.arn
        InputType       = "FilePath"
        Input           = "manifest.json"
      }
    }
  }
}