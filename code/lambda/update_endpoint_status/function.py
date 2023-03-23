import json
import logging
import os
import pathlib

import boto3
from botocore.exceptions import ClientError

# Set the logger level based on an environment variable
logger_level = os.getenv('LOGGER_LEVEL', 'INFO').upper()
logger = logging.getLogger()
logger.setLevel(logger_level)

session = boto3.session.Session()
sagemaker = session.client('sagemaker')


def handler(event, context):
    """Lambda Handler"""

    logger.info(event)
    try:

        response = sagemaker.describe_endpoint(EndpointName=event['EndpointName'])

        if response['EndpointStatus'] == 'InService':
            event['SageMakerEndpoint']['EndpointStatus'] = 'InService'
        elif response['EndpointStatus'] == "Failed":
            event['SageMakerEndpoint']['EndpointStatus'] = 'Failed'
        else:
            event['SageMakerEndpoint']['EndpointStatus'] = 'NotInService'

    except ClientError as error:
        logging.error(error, exc_info=True)
        raise error
    except Exception as error:
        logging.error(error, exc_info=True)
        raise error

    return event


# For running the script locally.
if __name__ == "__main__":
    path = pathlib.Path.cwd() / 'events/event.json'
    with open(str(path)) as f:
        handler(json.load(f), None)
