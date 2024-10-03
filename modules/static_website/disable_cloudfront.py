"""
CloudFront Distribution Disabler for AWS Lambda.
Disables a CloudFront distribution in response to a budget alert.
Uses boto3 to interact with AWS services and sends notifications via SNS.
"""

import json
import os

import boto3


def lambda_handler(event, context):
    """
    AWS Lambda function to disable a CloudFront distribution and send notifications.

    This function disables a specified CloudFront distribution in response to a budget alert.
    It then sends an SNS notification about the action taken or any errors encountered.

    Args:
        event (dict): The event dict that contains the parameters passed when the function
                      is invoked.
        context (object): The context in which the function is called.

    Returns:
        dict: A dictionary containing a statusCode and a JSON-formatted body message.
              - statusCode 200 and success message if the distribution is disabled successfully.
              - statusCode 500 and error message if an exception occurs.

    Environment Variables:
        DISTRIBUTION_ID (str): The ID of the CloudFront distribution to be disabled.
        SNS_TOPIC_ARN (str): The ARN of the SNS topic to publish notifications.

    Raises:
        Exception: Any exception that occurs during the execution of the function
                   will be caught, logged, and notified via SNS.
    """
    cloudfront = boto3.client("cloudfront")
    sns = boto3.client("sns")
    distribution_id = os.environ["DISTRIBUTION_ID"]

    try:
        # Get the current distribution config
        response = cloudfront.get_distribution_config(Id=distribution_id)
        etag = response["ETag"]
        config = response["DistributionConfig"]

        # Disable the distribution
        config["Enabled"] = False

        # Update the distribution with the new config
        cloudfront.update_distribution(
            DistributionConfig=config, Id=distribution_id, IfMatch=etag
        )

        message = f"CloudFront distribution {distribution_id} has been disabled due to budget alert."

        # Send SNS notification
        sns.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Message=message,
            Subject="CloudFront Distribution Disabled",
        )

        return {"statusCode": 200, "body": json.dumps(message)}
    except Exception as exc:
        error_message = f"Error disabling CloudFront distribution: {str(exc)}"
        print(error_message)

        # Send SNS notification for error
        sns.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Message=error_message,
            Subject="Error Disabling CloudFront Distribution",
        )

        return {"statusCode": 500, "body": json.dumps(error_message)}
