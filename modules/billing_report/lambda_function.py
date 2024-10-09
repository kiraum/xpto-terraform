"""AWS Cost Explorer Lambda function to report costs for various time periods."""

import datetime
import json
import os
import urllib.request

import boto3
from botocore.exceptions import ClientError

# Configurable cost thresholds for different time periods
DAILY_COST_THRESHOLD = float(os.environ.get("DAILY_COST_THRESHOLD", "0.01"))
WEEKLY_COST_THRESHOLD = float(os.environ.get("WEEKLY_COST_THRESHOLD", "1.00"))
MONTHLY_COST_THRESHOLD = float(os.environ.get("MONTHLY_COST_THRESHOLD", "4.00"))
YEARLY_COST_THRESHOLD = float(os.environ.get("YEARLY_COST_THRESHOLD", "48.00"))


def get_ssm_parameter(parameter_name):
    """
    Retrieve a parameter value from AWS Systems Manager Parameter Store.
    Args:
        parameter_name (str): The name of the parameter to retrieve.
    Returns:
        str: The decrypted value of the parameter.
    """
    ssm = boto3.client("ssm")
    response = ssm.get_parameter(Name=parameter_name, WithDecryption=True)
    return response["Parameter"]["Value"]


def send_slack_notification(message):
    """
    Send a notification to a Slack channel using a webhook URL stored in SSM.
    """
    webhook_url = get_ssm_parameter("/billing_report/slack_webhook_url")
    payload = json.dumps({"text": "AWS Cost Report", "blocks": message}).encode("utf-8")
    req = urllib.request.Request(
        webhook_url, data=payload, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as response:
        if response.getcode() != 200:
            print(
                f"Failed to send Slack notification. Status code: {response.getcode()}"
            )


def calculate_time_periods(time_period, current_date):
    """
    Calculate start and end dates for the given time period.
    """
    end = current_date - datetime.timedelta(days=1)

    if time_period == "daily":
        start = end
        compare_start = end - datetime.timedelta(days=1)
        compare_end = compare_start
    elif time_period == "weekly":
        start = end - datetime.timedelta(days=6)
        compare_start = start - datetime.timedelta(days=7)
        compare_end = compare_start + datetime.timedelta(days=6)
    elif time_period == "monthly":
        start = end.replace(day=1)
        compare_start = (start - datetime.timedelta(days=1)).replace(day=1)
        compare_end = start - datetime.timedelta(days=1)
    elif time_period == "yearly":
        start = end.replace(month=1, day=1)
        compare_start = start.replace(year=start.year - 1)
        compare_end = compare_start.replace(
            year=compare_start.year + 1
        ) - datetime.timedelta(days=1)
    else:
        raise ValueError(
            f"Invalid time period: {time_period}. Must be daily, weekly, monthly, or yearly."
        )

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


def generate_text_report(
    time_period,
    start,
    end,
    current_costs,
    compare_costs,
    unit,
    response,
    compare_response,
    cost_threshold,
    aws_account,
):
    """
    Generate a detailed text cost report.
    """
    text_template = """
- AWS Cost Report - {time_period} (Period: {start_date} to {end_date})

AWS Account: {aws_account}
Threshold: {threshold:.7f} {unit}

- Summary:
Current {time_period} cost: {current_costs:.7f} | Previous {time_period} cost: {compare_costs:.7f} {unit} | Difference: {difference:.7f} {unit}

- Breakdown by Service:
{service_breakdown}
    """

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

    service_breakdown = ""
    for service, cost in sorted(current_services.items()):
        previous_cost = previous_services.get(service, 0)
        difference = cost - previous_cost
        service_breakdown += f"{service}\nCurrent: {cost:.7f} {unit} || Previous: {previous_cost:.7f} {unit} || Difference: {difference:.7f} {unit}\n\n"

    return text_template.format(
        time_period=time_period,
        start_date=start.isoformat(),
        end_date=end.isoformat(),
        current_costs=current_costs,
        compare_costs=compare_costs,
        unit=unit,
        difference=current_costs - compare_costs,
        threshold=cost_threshold,
        service_breakdown=service_breakdown,
        aws_account=aws_account,
    )


def generate_slack_block_report(
    time_period,
    start,
    end,
    current_costs,
    compare_costs,
    unit,
    response,
    compare_response,
    cost_threshold,
    aws_account,
):
    """
    Generate a Slack block-formatted cost report.
    """
    header = {
        "type": "header",
        "text": {
            "type": "plain_text",
            "text": f"AWS Cost Report - {time_period.capitalize()}",
            "emoji": True,
        },
    }

    context = {
        "type": "context",
        "elements": [
            {
                "type": "plain_text",
                "text": f"Period: {start.isoformat()} to {end.isoformat()}",
                "emoji": True,
            },
            {
                "type": "plain_text",
                "text": f"AWS Account: {aws_account}",
                "emoji": True,
            },
        ],
    }

    summary = {
        "type": "section",
        "fields": [
            {
                "type": "mrkdwn",
                "text": f"*Current {time_period} cost:*\n{current_costs:.7f} {unit}",
            },
            {
                "type": "mrkdwn",
                "text": f"*Previous {time_period} cost:*\n{compare_costs:.7f} {unit}",
            },
            {
                "type": "mrkdwn",
                "text": f"*Difference:*\n{current_costs - compare_costs:.7f} {unit}",
            },
            {"type": "mrkdwn", "text": f"*Threshold:*\n{cost_threshold:.7f} {unit}"},
        ],
    }

    divider = {"type": "divider"}

    service_breakdown = []
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
            difference = cost - previous_cost
            service_breakdown.append(
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": f"*{service}*\nCurrent: {cost:.7f} {unit} | Previous: {previous_cost:.7f} {unit} | Difference: {difference:.7f} {unit}",
                    },
                }
            )

    blocks = [
        header,
        context,
        divider,
        summary,
        divider,
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": "*Breakdown by Service:*"},
        },
    ] + service_breakdown

    return {"blocks": blocks}


def send_sns(message, subject):
    """
    Send a message using AWS SNS.
    Args:
        message (str): The message to be sent.
        subject (str): The subject of the message.
    """
    sns = boto3.client("sns")
    topic_arn = os.environ["SNS_TOPIC_ARN"]

    if not topic_arn:
        raise ValueError("SNS_TOPIC_ARN must be set in the environment variables")

    try:
        response = sns.publish(TopicArn=topic_arn, Message=message, Subject=subject)
        print(f"Message sent to SNS! Message ID: {response['MessageId']}")
    except ClientError as exc:
        print(f"An error occurred while sending message via SNS: {exc}")


def lambda_handler(event, context):
    """
    AWS Lambda function to report AWS costs for various time periods.
    """
    ce = boto3.client("ce")
    sts = boto3.client("sts")
    time_period = event.get("time_period", "daily").lower()
    current_date = datetime.datetime.utcnow().date()

    try:
        aws_account = sts.get_caller_identity()["Account"]
        start, end, compare_start, compare_end = calculate_time_periods(
            time_period, current_date
        )

        response = ce.get_cost_and_usage(
            TimePeriod={
                "Start": start.strftime("%Y-%m-%d"),
                "End": (end + datetime.timedelta(days=1)).strftime("%Y-%m-%d"),
            },
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )
        compare_response = ce.get_cost_and_usage(
            TimePeriod={
                "Start": compare_start.strftime("%Y-%m-%d"),
                "End": (compare_end + datetime.timedelta(days=1)).strftime("%Y-%m-%d"),
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

        cost_threshold = {
            "daily": DAILY_COST_THRESHOLD,
            "weekly": WEEKLY_COST_THRESHOLD,
            "monthly": MONTHLY_COST_THRESHOLD,
            "yearly": YEARLY_COST_THRESHOLD,
        }.get(time_period, DAILY_COST_THRESHOLD)

        report = generate_text_report(
            time_period,
            start,
            end,
            current_costs,
            compare_costs,
            unit,
            response,
            compare_response,
            cost_threshold,
            aws_account,
        )

        if current_costs > cost_threshold:
            print("Cost threshold exceeded. Sending notification.")
            send_sns(
                report,
                f"AWS Cost Report - {time_period.capitalize()} (Period: {start.strftime('%Y-%m-%d')} to {end.strftime('%Y-%m-%d')})",
            )
            if os.environ.get("ENABLE_SLACK") == "true":
                slack_report = generate_slack_block_report(
                    time_period,
                    start,
                    end,
                    current_costs,
                    compare_costs,
                    unit,
                    response,
                    compare_response,
                    cost_threshold,
                    aws_account,
                )
                send_slack_notification(slack_report["blocks"])
        else:
            print(
                f"Total cost ({current_costs:.7f} {unit}) did not exceed the threshold ({cost_threshold:.7f} {unit}). No notification sent."
            )

        return {"statusCode": 200, "body": "Cost report generated successfully."}

    except ClientError as exc:
        message = f"An error occurred with the Cost Explorer API: {str(exc)}"
    except ValueError as exc:
        message = str(exc)
    except Exception as exc:
        message = f"An unexpected error occurred: {str(exc)}"
        print(f"Full error details: {exc}")

    return {"statusCode": 500, "body": message}
