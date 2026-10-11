# Step Functions Batch Processing

Serverless batch processing pipeline that queries DynamoDB records in paginated batches,
calls an external API per record, and updates the record status — all orchestrated by
AWS Step Functions and triggered on a schedule via EventBridge Scheduler.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                          │
│                                                                             │
│  ┌──────────────────────┐                                                   │
│  │  EventBridge         │                                                   │
│  │  Scheduler           │  rate(5 minutes)                                  │
│  │                      │─────────────────────────────────┐                 │
│  └──────────────────────┘                                 │                 │
│                                                           ▼                 │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     Step Functions State Machine                       │ │
│  │                                                                        │ │
│  │   ┌─────────────┐    ┌──────────────┐    ┌──────────────────────────┐ │ │
│  │   │ QueryBatch  │───►│ AreThereItems│───►│  ProcessItems            │ │ │
│  │   │   Lambda    │    │   (Choice)   │    │  Distributed Map         │ │ │
│  │   └─────────────┘    └──────────────┘    │  MaxConcurrency=5        │ │ │
│  │          ▲                               │  ┌──────────┐            │ │ │
│  │          │                               │  │ CallAPI  │            │ │ │
│  │          │           ┌──────────────┐    │  │  Lambda  │            │ │ │
│  │          └───────────│   NextPage   │◄───│  └────┬─────┘            │ │ │
│  │                      │   (Pass)     │    │       │                  │ │ │
│  │                      └──────────────┘    │  ┌────▼──────────┐       │ │ │
│  │                             ▲            │  │ UpdateStatus  │       │ │ │
│  │                             │            │  │    Lambda     │       │ │ │
│  │                      ┌──────┴───────┐    │  └───────────────┘       │ │ │
│  │                      │StripMapResult│◄───└──────────────────────────┘ │ │
│  │                      │  (Choice)    │                                  │ │
│  │                      └──────────────┘                                  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    VPC  (10.0.0.0/16)                               │   │
│  │                                                                     │   │
│  │  Private Subnets (Lambdas)          Public Subnets                  │   │
│  │  ┌──────────────────────────┐       ┌──────────────────────────┐   │   │
│  │  │ 10.0.1.0/24 us-east-1a  │       │ 10.0.101.0/24 us-east-1a │   │   │
│  │  │ 10.0.2.0/24 us-east-1b  │       │ 10.0.102.0/24 us-east-1b │   │   │
│  │  └──────────┬───────────────┘       └──────────┬───────────────┘   │   │
│  │             │ (DynamoDB Gateway                 │                   │   │
│  │             │  VPC Endpoint)        ┌───────────┴──────┐            │   │
│  │             │                       │   NAT Gateway    │            │   │
│  │  ┌──────────▼───────────────────┐   └──────────────────┘            │   │
│  │  │       DynamoDB               │                                   │   │
│  │  │   sfn-batch-events           │                                   │   │
│  │  │   GSI: letter_sent-index     │                                   │   │
│  │  └──────────────────────────────┘                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## State Machine Flow

```
                        ┌─────────────────────────────────────────┐
                        │              START                       │
                        │         input: {} or                     │
                        │  { last_evaluated_key: {...} }           │
                        └───────────────────┬─────────────────────┘
                                            │
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │            QueryBatch                    │
                        │  Lambda: sfn-batch-query-dynamodb        │
                        │  - GSI query: letter_sent = "false"      │
                        │  - Limit: 10 (BATCH_SIZE)                │
                        │  - Accepts last_evaluated_key for paging │
                        │  OutputPath: $.batch_result              │
                        │  Returns: { items, has_more,             │
                        │            last_evaluated_key }          │
                        └───────────────────┬─────────────────────┘
                                            │
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │           AreThereItems                  │
                        │           (Choice State)                 │
                        └──────────┬──────────────────┬───────────┘
                                   │                  │
                          items present           no items
                                   │                  │
                                   ▼                  ▼
                        ┌──────────────────┐    ┌──────────┐
                        │  ProcessItems    │    │   Done   │
                        │  (Distributed    │    │ (Succeed)│
                        │   Map State)     │    └──────────┘
                        │                 │
                        │  MaxConcurrency=5│
                        │  ToleratedFail%=5│
                        │                 │
                        │  ┌───────────────────────────────┐
                        │  │  Per item (child execution):  │
                        │  │                               │
                        │  │  ┌─────────────────────────┐  │
                        │  │  │        CallAPI           │  │
                        │  │  │  Lambda: sfn-batch-      │  │
                        │  │  │         call-api         │  │
                        │  │  │  Simulates API (~200ms)  │  │
                        │  │  └────────────┬────────────┘  │
                        │  │               │               │
                        │  │               ▼               │
                        │  │  ┌─────────────────────────┐  │
                        │  │  │      UpdateStatus        │  │
                        │  │  │  Lambda: sfn-batch-      │  │
                        │  │  │         update-status    │  │
                        │  │  │  Sets letter_sent=true   │  │
                        │  │  │  Sets letter_sent_date   │  │
                        │  │  └─────────────────────────┘  │
                        │  └───────────────────────────────┘
                        └───────────────┬─────────────────┘
                                        │
                                        ▼
                        ┌─────────────────────────────────────────┐
                        │          StripMapResults                 │
                        │           (Choice State)                 │
                        └──────────┬──────────────────┬───────────┘
                                   │                  │
                              has_more=true      has_more=false
                                   │                  │
                                   ▼                  ▼
                        ┌──────────────────┐    ┌──────────┐
                        │    NextPage      │    │   Done   │
                        │  (Pass State)    │    │ (Succeed)│
                        │  Passes only     │    └──────────┘
                        │  last_evaluated_ │
                        │  key forward     │
                        └────────┬─────────┘
                                 │
                                 └──────────────► QueryBatch (loop)
```

---

## DynamoDB Schema

| Field              | Type   | Notes                              |
|--------------------|--------|------------------------------------|
| `event_id`         | String | Partition key (UUID)               |
| `letter_sent`      | String | `"true"` / `"false"` — GSI hash key|
| `letter_sent_date` | String | ISO 8601 timestamp, set on update  |
| `message_body`     | String | Body of the message                |

**GSI:** `letter_sent-index` on `letter_sent` — enables efficient query for unprocessed records only.

> Note: `letter_sent` is stored as a String not Boolean because DynamoDB GSI hash keys
> must be type S, N, or B — booleans cannot be used as GSI keys.

---

## Infrastructure (Terraform)

| Resource                        | Name                          |
|---------------------------------|-------------------------------|
| VPC                             | sfn-batch-vpc (10.0.0.0/16)   |
| Private Subnets                 | us-east-1a, us-east-1b        |
| Public Subnets                  | us-east-1a, us-east-1b        |
| NAT Gateway                     | sfn-batch-vpc-us-east-1a      |
| DynamoDB Gateway VPC Endpoint   | vpce-02018678327372061        |
| DynamoDB Table                  | sfn-batch-events              |
| Lambda: Query                   | sfn-batch-query-dynamodb      |
| Lambda: API                     | sfn-batch-call-api            |
| Lambda: Update                  | sfn-batch-update-status       |
| Step Functions State Machine    | sfn-batch-state-machine       |
| EventBridge Scheduler           | sfn-batch-trigger             |

---

## Execution Result — Test Run (50 records)

**Execution ARN:**
```
arn:aws:states:us-east-1:022784798356:execution:sfn-batch-state-machine:44966951-a281-40a9-93fa-96263799e1cf
```

**Summary:**

| Field          | Value                              |
|----------------|------------------------------------|
| Status         | ✅ SUCCEEDED                       |
| Start          | 2026-10-11T09:13:21 EDT            |
| End            | 2026-10-11T09:13:43 EDT            |
| Total Duration | ~22 seconds                        |
| Records seeded | 50                                 |
| Batch size     | 10                                 |
| Pages          | 5 (+ 1 final empty page → Done)    |
| Concurrency    | 5 (Distributed Map)                |
| Input          | `{}`                               |
| Output         | `{"items":[],"has_more":false}`    |

**Pagination Timeline:**

```
09:13:21.536  ExecutionStarted
              │
09:13:21.559  ── Page 1: QueryBatch (Lambda warm: 152ms)
09:13:21.798  ── AreThereItems → ProcessItems
09:13:21.855  ── MapRunStarted  (10 items, 5 concurrent)
09:13:26.900  ── MapRunSucceeded                          [5.0s — cold start]
09:13:26.900  ── StripMapResults → has_more=true → NextPage
              │
09:13:26.900  ── Page 2: QueryBatch (Lambda warm: 104ms)
09:13:27.143  ── AreThereItems → ProcessItems
09:13:27.197  ── MapRunStarted
09:13:30.517  ── MapRunSucceeded                          [3.3s — warm]
09:13:30.517  ── StripMapResults → has_more=true → NextPage
              │
09:13:30.517  ── Page 3: QueryBatch (90ms)
09:13:30.764  ── MapRunStarted
09:13:34.302  ── MapRunSucceeded                          [3.5s]
09:13:34.302  ── StripMapResults → has_more=true → NextPage
              │
09:13:34.302  ── Page 4: QueryBatch (116ms)
09:13:34.563  ── MapRunStarted
09:13:38.414  ── MapRunSucceeded                          [3.9s]
09:13:38.414  ── StripMapResults → has_more=true → NextPage
              │
09:13:38.414  ── Page 5: QueryBatch (85ms)
09:13:38.645  ── MapRunStarted
09:13:42.775  ── MapRunSucceeded                          [4.1s]
09:13:42.775  ── StripMapResults → has_more=false
              │
09:13:42.775  ── Page 6: QueryBatch → items=[] → AreThereItems → Done
              │
09:13:43.066  ExecutionSucceeded
```

**Per-page Map duration breakdown:**

| Page | Items | MapRun Duration | Note              |
|------|-------|-----------------|-------------------|
| 1    | 10    | 5.0s            | Lambda cold start |
| 2    | 10    | 3.3s            | Warm              |
| 3    | 10    | 3.5s            | Warm              |
| 4    | 10    | 3.9s            | Warm              |
| 5    | 10    | 4.1s            | Warm              |

> Map duration per page = 200ms API delay × 2 rounds (10 items / 5 concurrency)
> + Lambda execution overhead + DynamoDB UpdateItem latency per item.

**DynamoDB verification post-execution:**

```bash
# Unprocessed (letter_sent=false)
$ aws dynamodb query ... --key-condition-expression "letter_sent = :v" \
    --expression-attribute-values '{":v":{"S":"false"}}' --select COUNT
0

# Processed (letter_sent=true)
$ aws dynamodb query ... --key-condition-expression "letter_sent = :v" \
    --expression-attribute-values '{":v":{"S":"true"}}' --select COUNT
50
```

---

## Throughput Analysis

| Config                        | API calls/sec |
|-------------------------------|---------------|
| batch=10, concurrency=5       | ~25/sec       |
| batch=10, concurrency=10      | ~50/sec       |
| batch=50, concurrency=50      | ~250/sec      |

**Formula:** `concurrency × (1000ms / api_delay_ms)`

The bottleneck at scale is the sequential pagination loop — each batch must complete
before the next page is fetched. Increasing `MaxConcurrency` to match `batch_size`
ensures each batch completes in a single parallel round (~200ms).

---

## Deploy

```bash
cd terraform
terraform init
terraform apply
```

## Seed Test Data

```bash
py scripts/seed_data.py sfn-batch-events 50
```

## Trigger Manually

```bash
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:us-east-1:022784798356:stateMachine:sfn-batch-state-machine \
  --input "{}"
```

## Configuration

| Variable               | Default          | Description                     |
|------------------------|------------------|---------------------------------|
| `aws_region`           | us-east-1        | AWS region                      |
| `batch_size`           | 10               | Records per Lambda invocation   |
| `api_delay_ms`         | 200              | Simulated API latency (ms)      |
| `schedule_expression`  | rate(5 minutes)  | EventBridge schedule            |
