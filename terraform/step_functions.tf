resource "aws_sfn_state_machine" "batch" {
  name     = "${local.name}-state-machine"
  role_arn = aws_iam_role.sfn.arn

  definition = jsonencode({
    Comment = "Batch letter processing with pagination"
    StartAt = "QueryBatch"

    States = {
      # Passes only last_evaluated_key (or nothing on first run) to the Lambda.
      # OutputPath keeps only batch_result so stale map_results never accumulate.
      QueryBatch = {
        Type       = "Task"
        Resource   = aws_lambda_function.query_dynamodb.arn
        ResultPath = "$.batch_result"
        OutputPath = "$.batch_result"
        Next       = "AreThereItems"
      }

      # Exit immediately if the batch came back empty
      AreThereItems = {
        Type = "Choice"
        Choices = [
          {
            Variable  = "$.items[0]"
            IsPresent = true
            Next      = "ProcessItems"
          }
        ]
        Default = "Done"
      }

      # Distributed Map — each item runs as a child execution, avoiding the
      # 25k event-history limit that inline Map hits at this scale (70k records)
      ProcessItems = {
        Type           = "Map"
        ItemsPath      = "$.items"
        ItemSelector   = { "item.$" = "$$.Map.Item.Value" }
        MaxConcurrency = 5
        ResultPath     = "$.map_results"
        ToleratedFailurePercentage = 5

        ItemProcessor = {
          ProcessorConfig = {
            Mode           = "DISTRIBUTED"
            ExecutionType  = "STANDARD"
          }
          StartAt = "CallAPI"
          States = {
            CallAPI = {
              Type       = "Task"
              Resource   = aws_lambda_function.call_api.arn
              ResultPath = "$.api_result"
              Next       = "UpdateStatus"
            }
            UpdateStatus = {
              Type      = "Task"
              Resource  = aws_lambda_function.update_status.arn
              InputPath = "$.api_result"
              End       = true
            }
          }
        }
        Next = "StripMapResults"
      }

      # Drop map_results; route directly to Done if no more pages (avoids missing last_evaluated_key)
      StripMapResults = {
        Type = "Choice"
        Choices = [
          {
            Variable      = "$.has_more"
            BooleanEquals = true
            Next          = "NextPage"
          }
        ]
        Default = "Done"
      }

      # Carry only last_evaluated_key into the next QueryBatch invocation
      NextPage = {
        Type = "Pass"
        Parameters = {
          "last_evaluated_key.$" = "$.last_evaluated_key"
        }
        Next = "QueryBatch"
      }

      Done = {
        Type = "Succeed"
      }
    }
  })
}
