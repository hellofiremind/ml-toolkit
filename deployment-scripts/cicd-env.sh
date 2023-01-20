# CI/CD specific values
export TF_VAR_CICD_SERVICE="ml-core-cicd"
export TF_VAR_STATE_BUCKET="${TF_VAR_CICD_SERVICE}-${TF_VAR_BUILD_STAGE}-${ACCOUNT}-state-bucket"
export S3_TERRAFORM_STATE_KEY="${S3_TERRAFORM_STATE_REGION}/${TF_VAR_CICD_SERVICE}/${TF_VAR_BUILD_STAGE}"

# NOTE: Change these values to the repository & branch you want to use for CI/CD
export TF_VAR_FULL_REPOSITORY_ID=""
export TF_VAR_BRANCH="development"