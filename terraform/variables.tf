variable "aws_region" {
  default = "us-east-1"
}

variable "project" {
  default = "sfn-batch"
}

variable "batch_size" {
  default = 10
}

variable "api_delay_ms" {
  default = 200
}

variable "schedule_expression" {
  description = "EventBridge cron/rate expression"
  default     = "rate(5 minutes)"
}
