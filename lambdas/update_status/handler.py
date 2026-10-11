import boto3
import os
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ["TABLE_NAME"]


def handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    event_id = event["event_id"]
    sent_date = datetime.now(timezone.utc).isoformat()

    table.update_item(
        Key={"event_id": event_id},
        UpdateExpression="SET letter_sent = :sent, letter_sent_date = :date",
        ExpressionAttributeValues={
            ":sent": "true",
            ":date": sent_date,
        },
    )

    return {"event_id": event_id, "letter_sent": True, "letter_sent_date": sent_date}
