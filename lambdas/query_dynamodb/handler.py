import boto3
import os

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "10"))


def handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    kwargs = {
        "IndexName": "letter_sent-index",
        "KeyConditionExpression": "letter_sent = :val",
        "ExpressionAttributeValues": {":val": "false"},
        "Limit": BATCH_SIZE,
    }

    # Support pagination via LastEvaluatedKey passed from state machine
    if event.get("last_evaluated_key"):
        kwargs["ExclusiveStartKey"] = event["last_evaluated_key"]

    response = table.query(**kwargs)

    return {
        "items": response.get("Items", []),
        "last_evaluated_key": response.get("LastEvaluatedKey"),
        "has_more": "LastEvaluatedKey" in response,
    }
