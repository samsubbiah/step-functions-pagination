output "dynamodb_table_name" {
  value = aws_dynamodb_table.events.name
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.batch.arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
