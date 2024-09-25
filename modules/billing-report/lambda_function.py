"""AWS Cost Explorer Lambda function to report daily costs."""

import datetime
import os

import boto3
from botocore.exceptions import ClientError


def lambda_handler(event, context):  # pylint: disable=unused-argument
    """
    Handle Lambda function invocation.

    Args:
        event (dict): Lambda function invocation event
        context (object): Lambda function context

    Returns:
        dict: Response containing status code and message
    """
    ce = boto3.client("ce")
    end = datetime.datetime.utcnow().date()
    start = end - datetime.timedelta(days=1)

    try:
        response = ce.get_cost_and_usage(
            TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
        )

        if response["ResultsByTime"]:
            total_cost = response["ResultsByTime"][0]["Total"]["UnblendedCost"]["Amount"]
            unit = response["ResultsByTime"][0]["Total"]["UnblendedCost"]["Unit"]
            message = f"Total AWS cost for {start.isoformat()}: {total_cost} {unit}"
        else:
            message = "No cost data available for the specified time period."
    except ClientError as exc:
        message = f"An error occurred: {str(exc)}"
    except Exception as exc:  # pylint: disable=broad-except
        message = f"An unexpected error occurred: {str(exc)}"

    print(message)
    send_sns(message)

    return {
        "statusCode": 200 if "error" not in message.lower() else 500,
        "body": message,
    }


def send_sns(message):
    """
    Send message to SNS topic.

    Args:
        message (str): Message to be sent
    """
    sns = boto3.client("sns")
    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]

    try:
        response = sns.publish(
            TopicArn=sns_topic_arn, Message=message, Subject="Daily AWS Cost Report"
        )
        print(f"Message published to SNS. Message ID: {response['MessageId']}")
    except ClientError as e:
        print(f"An error occurred while publishing to SNS: {e}")
