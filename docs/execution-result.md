# Execution Result — 44966951-a281-40a9-93fa-96263799e1cf

## Summary

| Field              | Value                                                                 |
|--------------------|-----------------------------------------------------------------------|
| Execution ID       | 44966951-a281-40a9-93fa-96263799e1cf                                  |
| Status             | ✅ SUCCEEDED                                                          |
| Start              | 2026-10-11T09:13:21.536 EDT                                           |
| End                | 2026-10-11T09:13:43.066 EDT                                           |
| Duration           | ~22 seconds                                                           |
| Records seeded     | 50                                                                    |
| Batch size         | 10                                                                    |
| Concurrency        | 5 (Distributed Map)                                                   |
| Pages processed    | 5 (+ 1 final empty page → Done)                                       |
| Input              | `{}`                                                                  |
| Output             | `{"items":[],"last_evaluated_key":null,"has_more":false}`             |

---

## State Machine Graph (All States Succeeded)

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                    sfn-batch-state-machine                          │
  │                                                                     │
  │   ┌──────────────┐                                                  │
  │   │  QueryBatch  │  ◄─────────────────────────────────┐            │
  │   │   ✅ x6      │                                     │            │
  │   └──────┬───────┘                                     │            │
  │          │                                             │            │
  │          ▼                                             │            │
  │   ┌──────────────┐   items=[]                          │            │
  │   │AreThereItems │ ──────────────────────────────┐     │            │
  │   │   ✅ x6      │                               │     │            │
  │   └──────┬───────┘                               │     │            │
  │          │ items present                         │     │            │
  │          ▼                                       │     │            │
  │   ┌──────────────┐                               │     │            │
  │   │ ProcessItems │                               │     │            │
  │   │  Distributed │                               │     │            │
  │   │  Map ✅ x5   │                               │     │            │
  │   │              │                               │     │            │
  │   │  ┌─────────┐ │                               │     │            │
  │   │  │ CallAPI │ │  5 concurrent child executions│     │            │
  │   │  │  ✅ x50 │ │                               │     │            │
  │   │  └────┬────┘ │                               │     │            │
  │   │       │      │                               │     │            │
  │   │  ┌────▼────┐ │                               │     │            │
  │   │  │ Update  │ │                               │     │            │
  │   │  │ Status  │ │                               │     │            │
  │   │  │  ✅ x50 │ │                               │     │            │
  │   │  └─────────┘ │                               │     │            │
  │   └──────┬───────┘                               │     │            │
  │          │                                       │     │            │
  │          ▼                                       │     │            │
  │   ┌──────────────┐  has_more=false               │     │            │
  │   │StripMapResult│ ──────────────────────────────┤     │            │
  │   │   ✅ x5      │                               │     │            │
  │   └──────┬───────┘                               │     │            │
  │          │ has_more=true                         │     │            │
  │          ▼                                       │     │            │
  │   ┌──────────────┐                               │     │            │
  │   │   NextPage   │ ────────────────────────────────────┘            │
  │   │   ✅ x5      │  passes last_evaluated_key                       │
  │   └──────────────┘                               │                  │
  │                                                  ▼                  │
  │                                           ┌──────────┐             │
  │                                           │   Done   │             │
  │                                           │    ✅    │             │
  │                                           └──────────┘             │
  └─────────────────────────────────────────────────────────────────────┘
```

---

## Pagination Timeline (from execution history)

```
09:13:21.536  ExecutionStarted  input={}
              │
              ├─ Page 1 ──────────────────────────────────────────────────
09:13:21.559  │  QueryBatch scheduled  (no last_evaluated_key — first page)
09:13:21.622  │  Lambda started
09:13:21.774  │  Lambda succeeded  →  10 items, has_more=true
09:13:21.798  │  AreThereItems  →  items present  →  ProcessItems
09:13:21.855  │  MapRunStarted   (10 items, MaxConcurrency=5)
09:13:26.900  │  MapRunSucceeded                        [5.0s — cold start]
09:13:26.900  │  StripMapResults  →  has_more=true  →  NextPage
              │
              ├─ Page 2 ──────────────────────────────────────────────────
09:13:26.900  │  QueryBatch scheduled  last_evaluated_key=6cc0a03e...
09:13:27.025  │  Lambda started
09:13:27.129  │  Lambda succeeded  →  10 items, has_more=true
09:13:27.143  │  AreThereItems  →  ProcessItems
09:13:27.197  │  MapRunStarted
09:13:30.517  │  MapRunSucceeded                        [3.3s — warm]
09:13:30.517  │  StripMapResults  →  has_more=true  →  NextPage
              │
              ├─ Page 3 ──────────────────────────────────────────────────
09:13:30.517  │  QueryBatch scheduled  last_evaluated_key=18af6df2...
09:13:30.659  │  Lambda started
09:13:30.749  │  Lambda succeeded  →  10 items, has_more=true
09:13:30.764  │  AreThereItems  →  ProcessItems
09:13:30.815  │  MapRunStarted
09:13:34.302  │  MapRunSucceeded                        [3.5s]
09:13:34.302  │  StripMapResults  →  has_more=true  →  NextPage
              │
              ├─ Page 4 ──────────────────────────────────────────────────
09:13:34.302  │  QueryBatch scheduled  last_evaluated_key=32d11a13...
09:13:34.434  │  Lambda started
09:13:34.550  │  Lambda succeeded  →  10 items, has_more=true
09:13:34.563  │  AreThereItems  →  ProcessItems
09:13:34.624  │  MapRunStarted
09:13:38.414  │  MapRunSucceeded                        [3.9s]
09:13:38.414  │  StripMapResults  →  has_more=true  →  NextPage
              │
              ├─ Page 5 ──────────────────────────────────────────────────
09:13:38.414  │  QueryBatch scheduled  last_evaluated_key=01e8bd8f...
09:13:38.543  │  Lambda started
09:13:38.630  │  Lambda succeeded  →  10 items, has_more=true
09:13:38.645  │  AreThereItems  →  ProcessItems
09:13:38.707  │  MapRunStarted
09:13:42.775  │  MapRunSucceeded                        [4.1s]
09:13:42.775  │  StripMapResults  →  has_more=false
              │
              ├─ Page 6 (final empty check) ──────────────────────────────
09:13:42.775  │  QueryBatch scheduled  last_evaluated_key=b4203804...
09:13:42.950  │  Lambda started
09:13:43.032  │  Lambda succeeded  →  items=[], has_more=false
09:13:43.050  │  AreThereItems  →  items=[]  →  Done
              │
09:13:43.066  ExecutionSucceeded
```

---

## Per-Page DynamoDB Update Results

### Page 1 — items 23, 37, 7, 41, 12, 47, 40, 6, 21, 18

| event_id (short)  | message #  | letter_sent | letter_sent_date (UTC)          |
|-------------------|------------|-------------|----------------------------------|
| c5cc2515          | msg 23     | true        | 2026-10-11T13:13:24.145272       |
| febd0e6b          | msg 37     | true        | 2026-10-11T13:13:24.112347       |
| 8c3b2f8b          | msg 7      | true        | 2026-10-11T13:13:24.046389       |
| 8a1aeede          | msg 41     | true        | 2026-10-11T13:13:24.121869       |
| d37cfd38          | msg 12     | true        | 2026-10-11T13:13:24.146975       |
| 7bebb6c7          | msg 47     | true        | 2026-10-11T13:13:25.307605       |
| 460f8a43          | msg 40     | true        | 2026-10-11T13:13:25.686034       |
| 8f2b7be0          | msg 6      | true        | 2026-10-11T13:13:25.683242       |
| 11c07fcf          | msg 21     | true        | 2026-10-11T13:13:25.702109       |
| 6cc0a03e          | msg 18     | true        | 2026-10-11T13:13:25.710410       |

> Round 1 (items 1-5): updated ~13:13:24 UTC
> Round 2 (items 6-10): updated ~13:13:25 UTC  ← 200ms API delay visible

### Page 2 — items 25, 30, 2, 33, 8, 14, 24, 36, 4, 19

| event_id (short)  | message #  | letter_sent | letter_sent_date (UTC)          |
|-------------------|------------|-------------|----------------------------------|
| a5c5531c          | msg 25     | true        | 2026-10-11T13:13:28.413484       |
| 85efe909          | msg 30     | true        | 2026-10-11T13:13:28.367760       |
| 387c6791          | msg 2      | true        | 2026-10-11T13:13:28.395402       |
| 10889241          | msg 33     | true        | 2026-10-11T13:13:28.381239       |
| 0da2b449          | msg 8      | true        | 2026-10-11T13:13:28.396474       |
| 42dffffc          | msg 14     | true        | 2026-10-11T13:13:29.223076       |
| fc859048          | msg 24     | true        | 2026-10-11T13:13:29.417151       |
| 0df5dbbb          | msg 36     | true        | 2026-10-11T13:13:29.413346       |
| 1e51ec14          | msg 4      | true        | 2026-10-11T13:13:29.614734       |
| 18af6df2          | msg 19     | true        | 2026-10-11T13:13:29.639244       |

### Page 3 — items 3, 39, 49, 45, 9, 27, 34, 15, 13, 28

| event_id (short)  | message #  | letter_sent | letter_sent_date (UTC)          |
|-------------------|------------|-------------|----------------------------------|
| 38c60c34          | msg 3      | true        | 2026-10-11T13:13:32.012575       |
| c20d1311          | msg 39     | true        | 2026-10-11T13:13:31.952930       |
| 39ff2a37          | msg 49     | true        | 2026-10-11T13:13:31.966724       |
| f0ffd659          | msg 45     | true        | 2026-10-11T13:13:31.978543       |
| d68aae0c          | msg 9      | true        | 2026-10-11T13:13:31.981821       |
| 40ec0bd0          | msg 27     | true        | 2026-10-11T13:13:32.803810       |
| 826f12bb          | msg 34     | true        | 2026-10-11T13:13:32.988799       |
| b1fa600b          | msg 15     | true        | 2026-10-11T13:13:33.086664       |
| d89dc85f          | msg 13     | true        | 2026-10-11T13:13:33.111627       |
| 32d11a13          | msg 28     | true        | 2026-10-11T13:13:33.624939       |

### Page 4 — items 43, 31, 11, 48, 46, 32, 29, 1, 16, 22

| event_id (short)  | message #  | letter_sent | letter_sent_date (UTC)          |
|-------------------|------------|-------------|----------------------------------|
| 2571c604          | msg 43     | true        | 2026-10-11T13:13:35.804403       |
| 88f4c4ea          | msg 31     | true        | 2026-10-11T13:13:35.786146       |
| 1dbb0c6d          | msg 11     | true        | 2026-10-11T13:13:35.777531       |
| 8c88e2ee          | msg 48     | true        | 2026-10-11T13:13:35.780569       |
| 058b8a10          | msg 46     | true        | 2026-10-11T13:13:35.766874       |
| 49eba269          | msg 32     | true        | 2026-10-11T13:13:36.597338       |
| cdae90d9          | msg 29     | true        | 2026-10-11T13:13:36.788964       |
| 36394bfb          | msg 1      | true        | 2026-10-11T13:13:36.791194       |
| d7930952          | msg 16     | true        | 2026-10-11T13:13:36.974503       |
| 01e8bd8f          | msg 22     | true        | 2026-10-11T13:13:37.462534       |

### Page 5 — items 5, 20, 42, 50, 35, 38, 26, 10, 17, 44

| event_id (short)  | message #  | letter_sent | letter_sent_date (UTC)          |
|-------------------|------------|-------------|----------------------------------|
| 6c4d5b0a          | msg 5      | true        | 2026-10-11T13:13:39.877245       |
| 95489948          | msg 20     | true        | 2026-10-11T13:13:39.844491       |
| 9ccc90ab          | msg 42     | true        | 2026-10-11T13:13:39.861067       |
| 1e9132a3          | msg 50     | true        | 2026-10-11T13:13:39.896156       |
| d9ddd3ef          | msg 35     | true        | 2026-10-11T13:13:39.839669       |
| 7f663bd3          | msg 38     | true        | 2026-10-11T13:13:40.766875       |
| 20c7c859          | msg 26     | true        | 2026-10-11T13:13:40.799839       |
| 7dd312f2          | msg 10     | true        | 2026-10-11T13:13:41.029972       |
| a434e7cb          | msg 17     | true        | 2026-10-11T13:13:41.019519       |
| b4203804          | msg 44     | true        | 2026-10-11T13:13:41.664505       |

---

## MapRun ARNs (Distributed Map child executions)

| Page | MapRun ARN (short)                                      | Duration |
|------|---------------------------------------------------------|----------|
| 1    | ...89603970-bf60-4087-9183-005223796647                 | 5.0s     |
| 2    | ...e4d8dccc-e491-4f4f-8e3f-74e28372976d                 | 3.3s     |
| 3    | ...5999a4c2-3bac-4abe-82f4-5b7ae6bba045                 | 3.5s     |
| 4    | ...0ec0b3bc-8ad7-461d-90dd-1913978a8662                 | 3.9s     |
| 5    | ...ae56bd43-69ea-4b38-92f4-6f8be58cc49e                 | 4.1s     |

---

## DynamoDB Verification

```bash
# After execution — unprocessed records
$ aws dynamodb query --table-name sfn-batch-events \
    --index-name letter_sent-index \
    --key-condition-expression "letter_sent = :v" \
    --expression-attribute-values '{":v":{"S":"false"}}' \
    --select COUNT
0

# After execution — processed records
$ aws dynamodb query --table-name sfn-batch-events \
    --index-name letter_sent-index \
    --key-condition-expression "letter_sent = :v" \
    --expression-attribute-values '{":v":{"S":"true"}}' \
    --select COUNT
50
```

All 50 records updated. ✅
