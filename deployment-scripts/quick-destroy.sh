source deployment-scripts/env.sh
export BUILD_STAGE=${TF_VAR_BUILD_STAGE}
export SERVICE=${TF_VAR_SERVICE}
export AWS_REGION=${TF_VAR_AWS_REGION}


applyTerraform() {
  rm -rf .terraform
  rm -rf .terraform.lock.hcl

  # Create State Bucket
  S3_TERRAFORM_STATE_BUCKET=${TF_VAR_STATE_BUCKET} S3_TERRAFORM_STATE_REGION=${S3_TERRAFORM_STATE_REGION} bash deployment-scripts/create-bucket.sh

  terraform init -backend-config="bucket=${TF_VAR_STATE_BUCKET}" -backend-config="key=${S3_TERRAFORM_STATE_KEY}" -backend-config="region=${S3_TERRAFORM_STATE_REGION}"

  terraform apply -destroy
}

applyServerless() {
  npm install -g serverless
  serverless plugin install -n serverless-python-requirements
  serverless plugin install -n serverless-offline
  serverless plugin install -n serverless-deployment-bucket
  npm install --dev serverless-better-credentials

  AWS_SDK_LOAD_CONFIG=1 npx serverless remove --stage "${TF_VAR_BUILD_STAGE}" --region "${TF_VAR_AWS_REGION}"
}

{
  applyServerless
} && {
  applyTerraform
}
