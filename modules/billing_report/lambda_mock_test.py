"""
This module contains mock functions for testing the AWS Cost Explorer Lambda function.
"""

import os
from unittest.mock import MagicMock

import boto3

from lambda_function import lambda_handler


def mock_boto3_client(service_name):
    """
    Mock boto3 client for testing purposes.

    Args:
        service_name (str): The name of the AWS service to mock

    Returns:
        MagicMock: A mock object for the specified AWS service
    """
    if service_name == "ce":
        mock_ce = MagicMock()
        mock_ce.get_cost_and_usage.return_value = {
            "ResultsByTime": [{"Total": {"UnblendedCost": {"Amount": "100.00", "Unit": "USD"}}}]
        }
        return mock_ce
    if service_name == "sns":
        mock_sns = MagicMock()
        mock_sns.publish.return_value = {"MessageId": "test-message-id"}
        return mock_sns
    return MagicMock()


boto3.client = mock_boto3_client

# Set environment variables
os.environ["SNS_TOPIC_ARN"] = "arn:aws:sns:us-east-1:123456789012:TestTopic"

# Create mock event and context
mock_event = {}
mock_context = MagicMock()


def test_lambda_handler():
    """
    Test the lambda_handler function with mock AWS services.
    """
    result = lambda_handler(mock_event, mock_context)
    print("Lambda function result:", result)


if __name__ == "__main__":
    test_lambda_handler()
