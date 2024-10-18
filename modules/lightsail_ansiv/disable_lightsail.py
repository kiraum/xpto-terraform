"""
Lightsail Container Service Disabler for AWS Lambda.
Disables a Lightsail container service in response to a budget alert.
Uses boto3 to interact with AWS services and sends notifications via SNS.
"""

import json
import os

import boto3


def lambda_handler(event, context):
    """
    AWS Lambda function to disable a Lightsail container service and send notifications.

    Args:
        event (dict): The event dict that contains the parameters passed when the function
                      is invoked.
        context (object): The context in which the function is called.

    Returns:
        dict: A dictionary containing a statusCode and a JSON-formatted body message.

    Environment Variables:
        CONTAINER_SERVICE_NAME (str): The name of the Lightsail container service to be disabled.
        SNS_TOPIC_ARN (str): The ARN of the SNS topic to publish notifications.
    """
    lightsail = boto3.client("lightsail")
    sns = boto3.client("sns")
    container_service_name = os.environ["CONTAINER_SERVICE_NAME"]

    try:
        # Disable the container service
        lightsail.update_container_service(
            serviceName=container_service_name,
            isDisabled=True
        )

        message = f"Lightsail container service {container_service_name} has been disabled due to budget alert."

        # Send SNS notification
        sns.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Message=message,
            Subject="Lightsail Container Service Disabled"
        )

        return {"statusCode": 200, "body": json.dumps(message)}
    except Exception as exc:
        error_message = f"Error disabling Lightsail container service: {str(exc)}"
        print(error_message)

        # Send SNS notification for error
        sns.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Message=error_message,
            Subject="Error Disabling Lightsail Container Service"
        )

        return {"statusCode": 500, "body": json.dumps(error_message)}

