# Plan-only tests of modules/logs on its own, against a mocked aws provider. Every value is
# synthetic: the documentation account id 123456789012 and ids of zeros.

mock_provider "aws" {
  override_during = plan

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/engine"
    }
  }
}

variables {
  log_group_prefix = "/pathways/test"
  kms_key_arn      = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
}

run "both_groups_are_encrypted_and_kept_for_the_retention" {
  command = plan

  module {
    source = "./modules/logs"
  }

  assert {
    condition = alltrue([
      for g in [aws_cloudwatch_log_group.engine, aws_cloudwatch_log_group.migrate] :
      g.kms_key_id == var.kms_key_arn && g.retention_in_days == 365
    ])
    error_message = "Both log groups are encrypted under the key given and keep logs for retention_days, 365 by default."
  }

  assert {
    condition     = output.engine_log_group_name == "/pathways/test/engine" && output.migrate_log_group_name == "/pathways/test/migrate"
    error_message = "The groups are <prefix>/engine and <prefix>/migrate."
  }
}

run "retention_is_the_callers" {
  command = plan

  module {
    source = "./modules/logs"
  }

  variables {
    retention_days = 731
  }

  assert {
    condition     = aws_cloudwatch_log_group.engine.retention_in_days == 731 && aws_cloudwatch_log_group.migrate.retention_in_days == 731
    error_message = "retention_days sets both groups' retention."
  }
}

run "retention_cloudwatch_does_not_offer_is_refused" {
  command = plan

  module {
    source = "./modules/logs"
  }

  variables {
    retention_days = 100
  }

  expect_failures = [var.retention_days]
}
