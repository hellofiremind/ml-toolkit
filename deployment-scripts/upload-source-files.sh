export CWD=$(pwd)

uploadWorkflowScripts() {
  # Creates tar file for Sagemaker Submit Directory
  (cd code/workflow && tar -czvf ../sourcedir.tar.gz .)

  # This uploads source files
  aws s3 cp "code/workflow/" "s3://${SOURCE_BUCKET}/code/" --recursive
  aws s3 cp code/sourcedir.tar.gz "s3://${SOURCE_BUCKET}/code/"
}

uploadManifestFile() {
  # This uploads source files
  aws s3 cp "config/manifest.json" "s3://${SOURCE_BUCKET}/config/manifest.json"
}

uploadWorkflowScripts
uploadManifestFile
