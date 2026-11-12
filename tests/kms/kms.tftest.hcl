# Plan-only tests of modules/kms on its own, against a mocked aws provider. Every value is
# synthetic: the documentation account id 123456789012 and ids of zeros.

mock_provider "aws" {
  override_during = plan

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      key_id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

variables {
  name             = "test"
  log_group_prefix = "/pathways/test"
  tags             = { "pathways:deployment" = "test" }
}

run "key_rotates_and_is_named_for_the_deployment" {
  command = plan

  module {
    source = "./modules/kms"
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation && aws_kms_key.this.deletion_window_in_days == 30
    error_message = "The key rotates, and its deletion window defaults to the longest AWS allows."
  }

  assert {
    condition     = output.alias_name == "alias/pathways-test" && aws_kms_alias.this.target_key_id == output.key_id
    error_message = "The alias is alias/pathways-<name>, on the key."
  }

  assert {
    condition     = aws_kms_key.this.tags == tomap({ "pathways:deployment" = "test" })
    error_message = "The key carries the tags given."
  }

  assert {
    condition     = output.key_arn == "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    error_message = "key_arn is the key's ARN."
  }
}

run "account_administers_the_key" {
  command = plan

  module {
    source = "./modules/kms"
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      s.sid == "AccountAdministers"
      && contains(flatten([for p in s.principals : tolist(p.identifiers)]), "arn:aws:iam::123456789012:root")
    ])
    error_message = "The account administers the key through IAM."
  }
}

run "logs_use_the_key_only_under_the_prefix" {
  command = plan

  module {
    source = "./modules/kms"
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.this.statement :
      contains(flatten([for p in s.principals : tolist(p.identifiers)]), "logs.us-east-1.amazonaws.com")
      && anytrue([for c in s.condition : c.variable == "kms:EncryptionContext:aws:logs:arn" && contains(c.values, "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/*")])
    ])
    error_message = "CloudWatch Logs may use the key only for the log groups under log_group_prefix."
  }
}

run "deletion_window_over_thirty_days_is_refused" {
  command = plan

  module {
    source = "./modules/kms"
  }

  variables {
    deletion_window_days = 31
  }

  expect_failures = [var.deletion_window_days]
}

run "prefix_ending_in_a_slash_is_refused" {
  command = plan

  module {
    source = "./modules/kms"
  }

  variables {
    log_group_prefix = "/pathways/test/"
  }

  expect_failures = [var.log_group_prefix]
}
