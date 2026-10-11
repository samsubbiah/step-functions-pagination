import time
import os

API_DELAY_MS = int(os.environ.get("API_DELAY_MS", "200"))


def handler(event, context):
    item = event["item"]

    # Simulate API latency
    time.sleep(API_DELAY_MS / 1000)

    return {
        "event_id": item["event_id"],
        "api_success": True,
        "message_body": item.get("message_body", ""),
    }
