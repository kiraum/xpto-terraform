"""AWS Cost Explorer Lambda function to report costs for various time periods."""

import datetime
import os

import boto3
from botocore.exceptions import ClientError

# Configurable cost thresholds for different time periods
DAILY_COST_THRESHOLD = float(os.environ.get("DAILY_COST_THRESHOLD", "0.01"))
WEEKLY_COST_THRESHOLD = float(os.environ.get("WEEKLY_COST_THRESHOLD", "0.01"))
MONTHLY_COST_THRESHOLD = float(os.environ.get("MONTHLY_COST_THRESHOLD", "0.01"))
YEARLY_COST_THRESHOLD = float(os.environ.get("YEARLY_COST_THRESHOLD", "0.01"))

DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE", "CostExplorerProcessedDates")


def get_last_processed_date(time_period):
    """
    Get the last processed date for the given time period from DynamoDB.

    Args:
        time_period (str): The time period to check (daily, weekly, monthly, yearly).

    Returns:
        str: The last processed date as an ISO format string, or None if not found.
    """
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(DYNAMODB_TABLE)

    try:
        response = table.get_item(Key={"time_period": time_period})
        return response.get("Item", {}).get("last_processed_date")
    except ClientError as e:
        print(f"Error retrieving last processed date: {e}")
        return None


def update_last_processed_date(time_period, date):
    """
    Update the last processed date for the given time period in DynamoDB.

    Args:
        time_period (str): The time period to update (daily, weekly, monthly, yearly).
        date (datetime.date): The date to set as the last processed date.
    """
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(DYNAMODB_TABLE)

    try:
        table.put_item(
            Item={"time_period": time_period, "last_processed_date": date.isoformat()}
        )
    except ClientError as e:
        print(f"Error updating last processed date: {e}")


def calculate_time_periods(time_period, current_date):
    """
    Calculate start and end dates for the given time period.

    Args:
        time_period (str): The time period to calculate (daily, weekly, monthly, yearly).
        current_date (datetime.date): The current date.

    Returns:
        tuple: start, end, compare_start, compare_end dates.

    Raises:
        ValueError: If an invalid time period is provided.
    """
    periods = {
        "daily": (1, 1),
        "weekly": (7, 7),
        "monthly": ("month", 1),
        "yearly": ("year", "year"),
    }

    if time_period not in periods:
        raise ValueError(
            f"Invalid time period: {time_period}. Must be daily, weekly, monthly, or yearly."
        )

    delta, compare_delta = periods[time_period]

    if time_period == "daily":
        start = current_date - datetime.timedelta(days=1)
        end = start
        compare_start = start - datetime.timedelta(days=1)
        compare_end = compare_start
    elif isinstance(delta, int):
        start = current_date - datetime.timedelta(days=delta)
        end = current_date
        compare_start = start - datetime.timedelta(days=compare_delta)
        compare_end = start
    else:
        start = current_date.replace(**{delta: 1})
        end = current_date
        compare_start = (start - datetime.timedelta(days=1)).replace(**{delta: 1})
        compare_end = start

    return start, end, compare_start, compare_end


def process_cost_data(response, compare_response):
    """
    Process the cost data from AWS Cost Explorer responses.

    Args:
        response (dict): The response from AWS Cost Explorer for the current period.
        compare_response (dict): The response from AWS Cost Explorer for the comparison period.

    Returns:
        tuple: current_costs, compare_costs, unit. Returns (None, None, None) if no data is available.
    """
    if not response["ResultsByTime"] or not compare_response["ResultsByTime"]:
        return None, None, None

    current_costs = sum(
        float(group["Metrics"]["UnblendedCost"]["Amount"])
        for result in response["ResultsByTime"]
        for group in result.get("Groups", [])
    )
    compare_costs = sum(
        float(group["Metrics"]["UnblendedCost"]["Amount"])
        for result in compare_response["ResultsByTime"]
        for group in result.get("Groups", [])
    )

    unit = next(
        (
            result["Groups"][0]["Metrics"]["UnblendedCost"]["Unit"]
            for result in response["ResultsByTime"]
            if result.get("Groups")
        ),
        "USD",
    )

    return current_costs, compare_costs, unit


def generate_cost_report(
    time_period,
    start,
    end,
    current_costs,
    compare_costs,
    unit,
    response,
    compare_response,
):
    """
    Generate a detailed cost report.

    Args:
        time_period (str): The time period of the report.
        start (datetime.date): The start date of the report.
        end (datetime.date): The end date of the report.
        current_costs (float): The total costs for the current period.
        compare_costs (float): The total costs for the comparison period.
        unit (str): The currency unit.
        response (dict): The response from AWS Cost Explorer for the current period.
        compare_response (dict): The response from AWS Cost Explorer for the comparison period.

    Returns:
        str: A formatted cost report message.
    """
    message = f"Total AWS cost for {time_period} ({start.isoformat()} to {end.isoformat()}): {current_costs:.7f} {unit}\n"
    message += f"Previous {time_period} cost: {compare_costs:.7f} {unit}\n"
    message += f"Difference: {current_costs - compare_costs:.7f} {unit}\n"

    cost_threshold = {
        "daily": DAILY_COST_THRESHOLD,
        "weekly": WEEKLY_COST_THRESHOLD,
        "monthly": MONTHLY_COST_THRESHOLD,
        "yearly": YEARLY_COST_THRESHOLD,
    }.get(time_period, DAILY_COST_THRESHOLD)

    message += f"Threshold: {cost_threshold:.7f} {unit}\n\n"
    message += "Breakdown by service:\n"

    current_services = {
        group["Keys"][0]: float(group["Metrics"]["UnblendedCost"]["Amount"])
        for result in response["ResultsByTime"]
        for group in result.get("Groups", [])
    }
    previous_services = {
        group["Keys"][0]: float(group["Metrics"]["UnblendedCost"]["Amount"])
        for result in compare_response["ResultsByTime"]
        for group in result.get("Groups", [])
    }

    for service, cost in current_services.items():
        if cost > 0:
            previous_cost = previous_services.get(service, 0)
            message += (
                f"{service}: {cost:.7f} {unit} (Previous: {previous_cost:.7f} {unit})\n"
            )

    return message


def send_sns(message):
    """
    Send message to SNS topic.

    Args:
        message (str): Message to be sent

    Raises:
        ClientError: If an error occurs while publishing to SNS.
    """
    sns = boto3.client("sns")
    sns_topic_arn = os.environ["SNS_TOPIC_ARN"]

    try:
        response = sns.publish(
            TopicArn=sns_topic_arn, Message=message, Subject="AWS Cost Report"
        )
        print(f"Message published to SNS. Message ID: {response['MessageId']}")
    except ClientError as e:
        print(f"An error occurred while publishing to SNS: {e}")


def lambda_handler(event, context):
    """
    AWS Lambda function to report AWS costs for various time periods.

    This function retrieves cost data from AWS Cost Explorer for a specified time period,
    compares it with the previous period, and generates a cost report. If the cost exceeds
    a predefined threshold, it sends a notification via SNS.

    Args:
        event (dict): The Lambda event object containing input parameters.
            - time_period (str, optional): The time period for the cost report.
              Valid values are 'daily', 'weekly', 'monthly', 'yearly'. Defaults to 'daily'.
        context (object): The Lambda context object (not used in this function).

    Returns:
        dict: A dictionary containing the status code and response body.
            - statusCode (int): HTTP status code (200 for success, 500 for errors).
            - body (str): A message describing the result or error.

    Raises:
        ClientError: If there's an issue with the AWS Cost Explorer API.
        ValueError: If an invalid time period is provided.
        Exception: For any other unexpected errors.

    Note:
        - The function uses environment variables for configuration:
          - DAILY_COST_THRESHOLD, WEEKLY_COST_THRESHOLD, MONTHLY_COST_THRESHOLD, YEARLY_COST_THRESHOLD:
            The cost thresholds for sending notifications for each time period.
          - SNS_TOPIC_ARN: The ARN of the SNS topic for notifications.
          - DYNAMODB_TABLE: The name of the DynamoDB table for tracking processed dates.
        - Cost data is retrieved using the AWS Cost Explorer API.
        - For daily reports, the function adjusts the date range to ensure full day coverage.
        - The function uses DynamoDB to prevent duplicate processing of the same time period.
    """
    ce = boto3.client("ce")
    time_period = event.get("time_period", "daily").lower()
    current_date = datetime.datetime.utcnow().date()

    try:
        start, end, compare_start, compare_end = calculate_time_periods(
            time_period, current_date
        )

        # Check if this period has already been processed
        last_processed_date = get_last_processed_date(time_period)
        if last_processed_date and last_processed_date >= end.isoformat():
            return {
                "statusCode": 200,
                "body": f"Cost data for {time_period} ending on {end.isoformat()} has already been processed.",
            }

        # For daily reports, we need to add one day to the end date to include the full day
        if time_period == "daily":
            end = end + datetime.timedelta(days=1)
            compare_end = compare_end + datetime.timedelta(days=1)

        response = ce.get_cost_and_usage(
            TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )
        compare_response = ce.get_cost_and_usage(
            TimePeriod={
                "Start": compare_start.isoformat(),
                "End": compare_end.isoformat(),
            },
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )

        current_costs, compare_costs, unit = process_cost_data(
            response, compare_response
        )

        if current_costs is None:
            message = f"No cost data available for the specified {time_period} period."
            return {"statusCode": 200, "body": message}

        # Select the appropriate cost threshold based on the time period
        cost_threshold = {
            "daily": DAILY_COST_THRESHOLD,
            "weekly": WEEKLY_COST_THRESHOLD,
            "monthly": MONTHLY_COST_THRESHOLD,
            "yearly": YEARLY_COST_THRESHOLD,
        }.get(time_period, DAILY_COST_THRESHOLD)

        if current_costs > cost_threshold:
            message = generate_cost_report(
                time_period,
                start,
                end - datetime.timedelta(days=1),  # Adjust end date for report
                current_costs,
                compare_costs,
                unit,
                response,
                compare_response,
            )
            print(message)
            send_sns(message)
        else:
            message = f"Total cost ({current_costs:.7f} {unit}) did not exceed the threshold ({cost_threshold:.7f} {unit}). No notification sent."
            print(message)

        # Update the last processed date
        update_last_processed_date(time_period, end - datetime.timedelta(days=1))

        return {"statusCode": 200, "body": message}

    except ClientError as exc:
        message = f"An error occurred with the Cost Explorer API: {str(exc)}"
    except ValueError as exc:
        message = str(exc)
    except Exception as exc:
        message = f"An unexpected error occurred: {str(exc)}"
        print(f"Full error details: {exc}")

    return {"statusCode": 500, "body": message}
