import boto3
import uuid
import sys

TABLE_NAME = sys.argv[1] if len(sys.argv) > 1 else "sfn-batch-events"
COUNT = int(sys.argv[2]) if len(sys.argv) > 2 else 25

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)

with table.batch_writer() as batch:
    for i in range(COUNT):
        batch.put_item(Item={
            "event_id": str(uuid.uuid4()),
            "letter_sent": "false",
            "letter_sent_date": "",
            "message_body": f"Hello, this is test message number {i + 1}.",
        })

print(f"Seeded {COUNT} items into {TABLE_NAME}")
