import json
import os

import boto3


def lambda_handler(event, context):
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
    except Exception as e:
        error_message = f"Error disabling CloudFront distribution: {str(e)}"
        print(error_message)

        # Send SNS notification for error
        sns.publish(
            TopicArn=os.environ["SNS_TOPIC_ARN"],
            Message=error_message,
            Subject="Error Disabling CloudFront Distribution",
        )

        return {"statusCode": 500, "body": json.dumps(error_message)}
