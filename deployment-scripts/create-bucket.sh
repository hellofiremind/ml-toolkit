export CWD=$(pwd)
bucketExists() {
  echo "${S3_TERRAFORM_STATE_BUCKET}"
  if aws s3api head-bucket --bucket "${S3_TERRAFORM_STATE_BUCKET}" >/dev/null
  then
    echo "Bucket exists; skipping creation"
  else
    echo "Bucket does not exist; creating"
    createTerraformBucket
  fi
}

# Creates bucket and adds s3 encryption to it once it is created
createTerraformBucket() {
  aws s3api create-bucket \
    --bucket "${S3_TERRAFORM_STATE_BUCKET}" \
    --region "${S3_TERRAFORM_STATE_REGION}" \
    --create-bucket-configuration LocationConstraint="${S3_TERRAFORM_STATE_REGION}" >/dev/null 2>&1
  echo Waiting for bucket to be created...
  aws s3api wait bucket-exists --bucket "${S3_TERRAFORM_STATE_BUCKET}"
  aws s3api put-bucket-encryption \
    --bucket "${S3_TERRAFORM_STATE_BUCKET}" \
    --server-side-encryption-configuration '{ "Rules": [ { "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm" : "AES256" } } ] }'
  echo Bucket created
}


bucketExists