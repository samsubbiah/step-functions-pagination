locals {
  lambda_defaults = {
    runtime       = "python3.12"
    timeout       = 30
    role_arn      = aws_iam_role.lambda.arn
    subnet_ids    = module.vpc.private_subnets
    sg_ids        = [aws_security_group.lambda.id]
    env_table     = aws_dynamodb_table.events.name
  }
}

# ── Zip archives ──────────────────────────────────────────────────────────────

data "archive_file" "query_dynamodb" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/query_dynamodb/handler.py"
  output_path = "${path.module}/../lambdas/query_dynamodb/package.zip"
}

data "archive_file" "call_api" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/call_api/handler.py"
  output_path = "${path.module}/../lambdas/call_api/package.zip"
}

data "archive_file" "update_status" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/update_status/handler.py"
  output_path = "${path.module}/../lambdas/update_status/package.zip"
}

# ── Lambda functions ──────────────────────────────────────────────────────────

resource "aws_lambda_function" "query_dynamodb" {
  function_name    = "${local.name}-query-dynamodb"
  filename         = data.archive_file.query_dynamodb.output_path
  source_code_hash = data.archive_file.query_dynamodb.output_base64sha256
  handler          = "handler.handler"
  runtime          = local.lambda_defaults.runtime
  role             = local.lambda_defaults.role_arn
  timeout          = local.lambda_defaults.timeout

  vpc_config {
    subnet_ids         = local.lambda_defaults.subnet_ids
    security_group_ids = local.lambda_defaults.sg_ids
  }

  environment {
    variables = {
      TABLE_NAME = local.lambda_defaults.env_table
      BATCH_SIZE = var.batch_size
    }
  }
}

resource "aws_lambda_function" "call_api" {
  function_name    = "${local.name}-call-api"
  filename         = data.archive_file.call_api.output_path
  source_code_hash = data.archive_file.call_api.output_base64sha256
  handler          = "handler.handler"
  runtime          = local.lambda_defaults.runtime
  role             = local.lambda_defaults.role_arn
  timeout          = local.lambda_defaults.timeout

  vpc_config {
    subnet_ids         = local.lambda_defaults.subnet_ids
    security_group_ids = local.lambda_defaults.sg_ids
  }

  environment {
    variables = {
      API_DELAY_MS = var.api_delay_ms
    }
  }
}

resource "aws_lambda_function" "update_status" {
  function_name    = "${local.name}-update-status"
  filename         = data.archive_file.update_status.output_path
  source_code_hash = data.archive_file.update_status.output_base64sha256
  handler          = "handler.handler"
  runtime          = local.lambda_defaults.runtime
  role             = local.lambda_defaults.role_arn
  timeout          = local.lambda_defaults.timeout

  vpc_config {
    subnet_ids         = local.lambda_defaults.subnet_ids
    security_group_ids = local.lambda_defaults.sg_ids
  }

  environment {
    variables = {
      TABLE_NAME = local.lambda_defaults.env_table
    }
  }
}
