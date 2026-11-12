# Plan-only tests of modules/iam on its own, against a mocked aws provider. The statements are
# asserted on the policy documents' arguments; the mocked documents' JSON is a fixed empty policy.
# Every value is synthetic: the documentation account id 123456789012 and ids of zeros.

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

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/pathways-test"
    }
  }
}

variables {
  name   = "test"
  images = ["registry.example.com/integration/project:1@sha256:0000000000000000000000000000000000000000000000000000000000000000", null]
  secrets = {
    PATHWAYS_DATABASE_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
  }
  kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"]
  log_group_arns = [
    "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/engine",
    "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/migrate",
  ]
}

run "roles_are_assumed_by_ecs_for_this_account_only" {
  command = plan

  module {
    source = "./modules/iam"
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.ecs_tasks_assume.statement :
      contains(flatten([for p in s.principals : tolist(p.identifiers)]), "ecs-tasks.amazonaws.com")
      && anytrue([for c in s.condition : c.variable == "aws:SourceAccount" && toset(c.values) == toset(["123456789012"])])
    ])
    error_message = "Only ECS acting for this account may assume the roles."
  }

  assert {
    condition     = output.execution_role_name == "pathways-test-execution" && output.task_role_name == "pathways-test-task"
    error_message = "The roles are pathways-<name>-execution and pathways-<name>-task."
  }
}

run "the_one_inline_policy_is_the_execution_roles" {
  command = plan

  module {
    source = "./modules/iam"
  }

  assert {
    condition     = aws_iam_role_policy.execution.role == aws_iam_role.execution.id
    error_message = "The module's one inline policy is on the execution role: the task role starts with none."
  }
}

run "execution_role_reads_exactly_the_injected_secrets" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    secrets = {
      PATHWAYS_DATABASE_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
      PATHWAYS_KEY_2026_11  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf:key::"
      PATHWAYS_TOKEN        = "arn:aws:ssm:us-east-1:123456789012:parameter/test/token"
    }
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "ReadSecrets" && toset(s.resources) == toset([
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf",
      ])
    ])
    error_message = "The execution role reads exactly the injected secrets, named by their ARNs without the JSON key."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "ReadParameters" && toset(s.resources) == toset(["arn:aws:ssm:us-east-1:123456789012:parameter/test/token"])
    ])
    error_message = "The execution role reads exactly the injected SSM parameters."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "DecryptSecrets" && toset(s.resources) == toset(var.kms_key_arns)
    ])
    error_message = "The execution role decrypts with the keys given, and no other."
  }
}

run "execution_role_writes_only_the_log_groups_given" {
  command = plan

  module {
    source = "./modules/iam"
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "WriteLogs" && toset(s.resources) == toset([
        "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/engine:*",
        "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/migrate:*",
      ])
    ])
    error_message = "The execution role writes the streams of the log groups given, and no other."
  }
}

run "registry_credentials_are_readable" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    repository_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/registry-AbCdEf"
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "ReadSecrets" && contains(s.resources, "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/registry-AbCdEf")
    ])
    error_message = "The execution role reads the private registry's credentials."
  }
}

run "ecr_image_reads_its_own_repository_only" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    images = ["123456789012.dkr.ecr.us-east-1.amazonaws.com/integration/project@sha256:0000000000000000000000000000000000000000000000000000000000000000", null]
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "PullImage" && toset(s.resources) == toset(["arn:aws:ecr:us-east-1:123456789012:repository/integration/project"])
    ])
    error_message = "An ECR image gives the execution role its own repository, and no other."
  }
}

run "migrate_image_in_another_repository_is_readable_too" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    images = [
      "123456789012.dkr.ecr.us-east-1.amazonaws.com/integration/project@sha256:0000000000000000000000000000000000000000000000000000000000000000",
      "123456789012.dkr.ecr.us-east-1.amazonaws.com/integration/next:2@sha256:1111111111111111111111111111111111111111111111111111111111111111",
    ]
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "PullImage" && toset(s.resources) == toset([
        "arn:aws:ecr:us-east-1:123456789012:repository/integration/project",
        "arn:aws:ecr:us-east-1:123456789012:repository/integration/next",
      ])
    ])
    error_message = "Each ECR image's repository is readable, and no other."
  }
}

run "image_outside_ecr_reads_no_ecr" {
  command = plan

  module {
    source = "./modules/iam"
  }

  assert {
    condition     = length([for s in data.aws_iam_policy_document.execution.statement : s if startswith(coalesce(s.sid, "none"), "Ecr") || coalesce(s.sid, "none") == "PullImage"]) == 0
    error_message = "An image outside ECR gives the execution role no ECR permission."
  }
}

run "secret_that_is_not_an_arn_is_refused" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    secrets = { PATHWAYS_KEY = "plain" }
  }

  expect_failures = [var.secrets]
}

run "no_log_group_is_refused" {
  command = plan

  module {
    source = "./modules/iam"
  }

  variables {
    log_group_arns = []
  }

  expect_failures = [var.log_group_arns]
}
