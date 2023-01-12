import json
import logging
import os
import pathlib
import shutil
import traceback
import uuid
from datetime import datetime
from zipfile import ZipFile

import boto3

session = boto3.session.Session()
s3_client = session.client('s3')
code_pipeline = session.client('codepipeline')

# Set the logger level based on an environment variable
logger_level = os.getenv('LOGGER_LEVEL', 'INFO').upper()
logger = logging.getLogger()
logger.setLevel(logger_level)

KMS_KEY_ID = os.getenv('KMS_KEY_ID')
MACHINE_LEARNING_BUCKET = os.getenv('MACHINE_LEARNING_BUCKET')
SOURCE_BUCKET = os.getenv('SOURCE_BUCKET')


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

    # Global parameters
    payload['SageMakerSubmitDirectory'] = f"s3://{SOURCE_BUCKET}/code/sourcedir.tar.gz"
    payload['InstanceType'] = 'ml.m5.xlarge'

    # Pre-Processing Parameters
    payload['ProcessingJobName'] = f'ml-core-preprocessing-job-{dt_string}'
    payload['ProcessingImageUri'] = '141502667606.dkr.ecr.eu-west-1.amazonaws.com/sagemaker-scikit-learn:0.23-1-cpu-py3'
    payload['ProcessingCodeUri'] = f's3://{SOURCE_BUCKET}/code/preprocess.py'
    payload["ProcessingInputLocation"] = f"s3://{MACHINE_LEARNING_BUCKET}/{dt_string}/source/"
    payload["ProcessingTrainLocation"] = f"s3://{MACHINE_LEARNING_BUCKET}/{dt_string}/preprocessing/train"
    payload["ProcessingTestLocation"] = f"s3://{MACHINE_LEARNING_BUCKET}/{dt_string}/preprocessing/test"
    payload["ProcessingModelLocation"] = f"s3://{MACHINE_LEARNING_BUCKET}/{dt_string}/preprocessing/scalar_model"

    # Training Parameters
    payload['TrainingJobName'] = f'ml-core-training-job-{dt_string}'
    payload['TrainingImageUri'] = '763104351884.dkr.ecr.eu-west-1.amazonaws.com/tensorflow-training:2.4.1-cpu-py37'
    payload['TrainingCodeUri'] = f's3://{SOURCE_BUCKET}/code/sourcedir.tar.gz'
    payload["TrainingOutputLocation"] = f"s3://{MACHINE_LEARNING_BUCKET}/{dt_string}/training"
    payload['TrainingHyperParameters'] = json.dumps(
        {
            "epochs": "100",
            "sagemaker_region": session.region_name,
            "sagemaker_program": "train.py",
            "sagemaker_container_log_level": "20",
            "sagemaker_submit_directory": payload['SageMakerSubmitDirectory'],
            "model_dir": f"s3://{MACHINE_LEARNING_BUCKET}/{dt_string}/training/model"

        }
    )

    # Evaluation Parameters
    payload['EvaluationJobName'] = f'ml-core-evaluation-job-{dt_string}'
    payload['EvaluationCodeUri'] = f's3://{SOURCE_BUCKET}/code/evaluation.py'
    payload["EvaluationOutputLocation"] = f"s3://{MACHINE_LEARNING_BUCKET}/{dt_string}/evaluation/output"

    # Model Parameters
    payload['ModelName'] = f'ml-core-model-{dt_string}'

    # Inference Parameters
    payload['InferenceImageUri'] = '763104351884.dkr.ecr.eu-west-1.amazonaws.com/tensorflow-inference:2.4.1-cpu'
    payload['InferenceInputLocation'] = f's3://{MACHINE_LEARNING_BUCKET}/{dt_string}/inference/'
    payload['InferenceOutputLocation'] = f's3://{MACHINE_LEARNING_BUCKET}/{dt_string}/inference/output/'

    return payload


def create_io_folders(paths: list):
    """Creates the specified path in S3 for input data."""
    for p in paths:
        s3_client.put_object(Bucket=MACHINE_LEARNING_BUCKET, Key=(p.split(f'{MACHINE_LEARNING_BUCKET}/')[-1]))


def find_artifact(artifacts):
    """Returns artifact from artifacts."""
    for artifact in artifacts:
        return artifact

    raise Exception('Input artifact named "{0}" not found in event')


def read_manifest(artifact):
    """Reads JSON file and returns payload"""
    bucket = artifact['location']['s3Location']['bucketName']
    key = artifact['location']['s3Location']['objectKey']

    obj = s3_client.get_object(Bucket=bucket, Key=key)['Body'].read().decode()

    return json.loads(obj)


def put_job_success(job):
    """Notify CodePipeline of a successful job"""
    logger.info(f'CodePipeline Job ID: {job}')
    code_pipeline.put_job_success_result(jobId=job)
    logger.info('Success')


def put_job_failure(job, message):
    """Notify CodePipeline of a failed job"""
    code_pipeline.put_job_failure_result(jobId=job, failureDetails={
        'message': message, 'type': 'JobFailed'})


def handler(event, context):
    """Lambda handler."""
    job_id = event['CodePipeline.job']['id']

    try:
        job_data = event['CodePipeline.job']['data']
        input_artifact = find_artifact(job_data['inputArtifacts'])
        output_artifact = find_artifact(job_data['outputArtifacts'])

        payload = read_manifest(input_artifact)

        # manipulate payload
        payload = update_payload(payload)
        create_io_folders([payload['ProcessingInputLocation'],
                           payload['InferenceInputLocation']])
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


# For running the script locally.
if __name__ == "__main__":
    path = pathlib.Path.cwd() / 'events/event.json'
    with open(str(path)) as f:
        handler(json.load(f), None)
