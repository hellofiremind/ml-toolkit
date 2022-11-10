import json
import os
import pathlib
import shutil
import tempfile
import traceback
import uuid
import zipfile
from datetime import datetime
from zipfile import ZipFile

import boto3

session = boto3.session.Session()
s3_client = session.client('s3')
code_pipeline = session.client('codepipeline')

KMS_KEY_ID = os.getenv('KMS_KEY_ID')


def create_artifact(payload):
    """Create artifact zip"""
    artifact_dir = '/tmp/output_artifacts/' + str(uuid.uuid4())
    artifact_file = artifact_dir + '/files/manifest.json'
    zipped_artifact_file = artifact_dir + '/artifact.zip'

    try:
        shutil.rmtree(artifact_dir + '/files/')
    except Exception:
        pass
    try:
        os.remove(zipped_artifact_file)
    except Exception:
        pass

    os.makedirs(artifact_dir + '/files/')
    with open(artifact_file, 'w') as outfile:
        json.dump(payload, outfile)

    with ZipFile(zipped_artifact_file, 'w') as zipped_artifact:
        zipped_artifact.write(artifact_file, os.path.basename(artifact_file))

    return zipped_artifact_file


def update_payload(payload):
    """Updates payload for input to step functions."""
    now = datetime.now()
    dt_string = now.strftime("%d-%m-%Y-%H-%M")

    payload['BatchOnly'] = 'True'

    # The name is set here to ensure that if a retry is executed on CodePipline, the transform job is unique to the
    # account
    payload["TransformJobName"] = f'ml-core-transform-job-{dt_string}'

    return payload


def find_artifact(artifacts):
    """Returns artifact from artifacts."""
    for artifact in artifacts:
        return artifact

    raise Exception('Input artifact named "{0}" not found in event')


def read_manifest(artifact):
    """Reads JSON file and returns payload"""
    tmp_file = tempfile.NamedTemporaryFile()
    bucket = artifact['location']['s3Location']['bucketName']
    key = artifact['location']['s3Location']['objectKey']

    with tempfile.NamedTemporaryFile() as tmp_file:
        s3_client.download_file(bucket, key, tmp_file.name)
        with zipfile.ZipFile(tmp_file.name, 'r') as zip:
            return json.loads(zip.read('output.json').decode())


def put_job_success(job):
    """Notify CodePipeline of a successful job"""
    print('CodePipeline Job ID:', job)
    code_pipeline.put_job_success_result(jobId=job)
    print('Success')


def put_job_failure(job, message):
    """Notify CodePipeline of a failed job"""
    code_pipeline.put_job_failure_result(jobId=job, failureDetails={
                                         'message': message, 'type': 'JobFailed'})


def handler(event, context):
    print(event)
    """Lambda handler."""
    job_id = event['CodePipeline.job']['id']

    try:
        job_data = event['CodePipeline.job']['data']
        input_artifact = find_artifact(job_data['inputArtifacts'])
        output_artifact = find_artifact(job_data['outputArtifacts'])

        payload = read_manifest(input_artifact)

        # manipulate payload
        payload = update_payload(payload)
        zipped_artifact_file = create_artifact(payload)

        s3_client.upload_file(
            zipped_artifact_file, output_artifact['location']['s3Location']['bucketName'],
            output_artifact['location']['s3Location']['objectKey'],
            ExtraArgs={
                "ServerSideEncryption": "aws:kms",
                "SSEKMSKeyId": KMS_KEY_ID
            }
        )

        put_job_success(job_id)

    except Exception as e:
        # If any other exceptions which we didn't expect are raised
        # then fail the job and log the exception message.
        traceback.print_exc()
        put_job_failure(job_id, 'Function exception: ' + str(e))

    return "Complete."


# For running the script locally (must ensure, bucket and key are valid)
if __name__ == "__main__":
    path = pathlib.Path.cwd() / 'events/event.json'
    with open(str(path)) as f:
        handler(json.load(f), None)
