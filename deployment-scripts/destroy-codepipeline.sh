source deployment-scripts/env.sh
source deployment-scripts/cicd-env.sh

applyTerraform() {
  # Create State Bucket
  S3_TERRAFORM_STATE_BUCKET=${TF_VAR_STATE_BUCKET} S3_TERRAFORM_STATE_REGION=${S3_TERRAFORM_STATE_REGION} bash deployment-scripts/create-bucket.sh

  cd cicd || exit
  terraform init -backend-config="bucket=${TF_VAR_STATE_BUCKET}" -backend-config="key=${S3_TERRAFORM_STATE_KEY}" -backend-config="region=${S3_TERRAFORM_STATE_REGION}"
  terraform apply -destroy
}

applyTerraform
