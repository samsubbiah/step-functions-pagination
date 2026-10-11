resource "aws_scheduler_schedule" "batch_trigger" {
  name       = "${local.name}-trigger"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.schedule_expression

  target {
    arn      = aws_sfn_state_machine.batch.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({})

    retry_policy {
      maximum_retry_attempts = 2
    }
  }
}
