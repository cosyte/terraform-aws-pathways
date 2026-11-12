# Plan-only tests of the root module: how main.tf wires the submodules together, what the root's
# outputs carry, and which root inputs are refused. What each submodule does on its own is tested in
# tests/<name>. Every run block is `command = plan` against a mocked aws provider: no credentials,
# no API call, no state, nothing created. scripts/test.sh refuses a run block that does not say
# `command = plan` and a file that does not mock aws.
#
# Every value is synthetic: the documentation account id 123456789012, ids of zeros and counting
# digits, names on example.com, and an image digest of zeros.

mock_provider "aws" {
  override_during = plan

  # A mocked policy document still has to be valid JSON: the roles and the key read it.
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

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      id  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/engine"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/pathways-test"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address = "pathways-test.example.com"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      id  = "arn:aws:ecs:us-east-1:123456789012:cluster/pathways-test"
      arn = "arn:aws:ecs:us-east-1:123456789012:cluster/pathways-test"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/pathways-test:1"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/test/0123456789abcdef"
      dns_name = "test.example.com"
      zone_id  = "Z0000000000000000000"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/0123456789abcdef"
    }
  }

  mock_resource "aws_security_group" {
    defaults = {
      id = "sg-00000000000000000"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id     = "pathways-test-00000000000000000000000001"
      bucket = "pathways-test-00000000000000000000000001"
      arn    = "arn:aws:s3:::pathways-test-00000000000000000000000001"
    }
  }

  mock_resource "aws_transfer_server" {
    defaults = {
      id       = "s-00000000000000000"
      arn      = "arn:aws:transfer:us-east-1:123456789012:server/s-00000000000000000"
      endpoint = "s-00000000000000000.server.transfer.us-east-1.amazonaws.com"
    }
  }
}

variables {
  name                = "test"
  vpc_id              = "vpc-00000000000000000"
  private_subnet_ids  = ["subnet-00000000000000001", "subnet-00000000000000002"]
  allowed_cidr_blocks = ["10.20.0.0/16"]
  image               = "registry.example.com/integration/project:1@sha256:0000000000000000000000000000000000000000000000000000000000000000"
  mllp_sources = {
    adt = { port = 2575 }
  }
}

# ---------------------------------------------------------------------------
# The outputs, each from the submodule that owns it
# ---------------------------------------------------------------------------

run "outputs_come_from_the_submodules" {
  command = plan

  assert {
    condition = (
      output.cluster_name == "pathways-test"
      && output.cluster_arn == "arn:aws:ecs:us-east-1:123456789012:cluster/pathways-test"
      && output.service_name == "pathways-test-engine"
      && output.engine_task_definition_arn == "arn:aws:ecs:us-east-1:123456789012:task-definition/pathways-test:1"
      && output.migrate_task_definition_arn == "arn:aws:ecs:us-east-1:123456789012:task-definition/pathways-test:1"
    )
    error_message = "The cluster, service and task definition outputs come from the ecs submodule."
  }

  assert {
    condition = (
      output.task_role_name == "pathways-test-task"
      && output.task_role_arn == "arn:aws:iam::123456789012:role/pathways-test"
      && output.execution_role_arn == "arn:aws:iam::123456789012:role/pathways-test"
    )
    error_message = "The role outputs come from the iam submodule."
  }

  assert {
    condition = (
      output.kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
      && output.database_address == "pathways-test.example.com"
      && output.database_url_secret_arn == "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
    )
    error_message = "The key, database address and database URL secret outputs come from the kms and database submodules."
  }

  assert {
    condition     = output.engine_log_group_name == "/pathways/test/engine" && output.migrate_log_group_name == "/pathways/test/migrate"
    error_message = "The log groups live under /pathways/<name>, the prefix the key's policy lets CloudWatch Logs use."
  }

  assert {
    condition = (
      output.engine_security_group_id == "sg-00000000000000000"
      && output.nlb_dns_name == "test.example.com"
      && output.nlb_zone_id == "Z0000000000000000000"
      && output.alb_dns_name == null
      && output.alb_zone_id == null
    )
    error_message = "One MLLP source and no HTTP source: a network load balancer and no application load balancer."
  }

  assert {
    condition = jsondecode(output.migrate_network_configuration) == {
      awsvpcConfiguration = {
        subnets        = ["subnet-00000000000000001", "subnet-00000000000000002"]
        securityGroups = ["sg-00000000000000000"]
        assignPublicIp = "DISABLED"
      }
    }
    error_message = "The migrate RunTask runs privately, in the private subnets and the security group the database admits."
  }
}

# ---------------------------------------------------------------------------
# The wiring between the submodules
# ---------------------------------------------------------------------------

run "database_and_logs_use_the_deployment_key" {
  command = plan

  assert {
    condition     = module.database.storage_kms_key_arn == module.kms.key_arn
    error_message = "With no database_kms_key_arn the database is encrypted under the deployment's key."
  }
}

run "database_key_from_caller_reaches_the_database" {
  command = plan

  variables {
    database_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }

  assert {
    condition     = module.database.storage_kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    error_message = "database_kms_key_arn reaches the database's storage."
  }

  assert {
    condition     = output.kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    error_message = "The deployment's own key is still created, for the secret and the logs."
  }
}

run "engine_reads_the_database_url_from_the_database_secret" {
  command = plan

  variables {
    environment = { PATHWAYS_STORAGE = "postgres" }
    secrets     = { PATHWAYS_KEY_2026_11 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf:key::" }
  }

  assert {
    condition = module.ecs.engine_container.secrets == [
      { name = "PATHWAYS_DATABASE_URL", valueFrom = output.database_url_secret_arn },
      { name = "PATHWAYS_KEY_2026_11", valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/master-key-AbCdEf:key::" },
    ]
    error_message = "The database module's secret and the caller's secrets are injected through secrets, valueFrom their ARNs."
  }

  assert {
    condition     = module.ecs.engine_container.environment == [{ name = "PATHWAYS_STORAGE", value = "postgres" }]
    error_message = "Only the plain settings are in environment."
  }

  assert {
    condition     = module.ecs.migrate_container.secrets == module.ecs.engine_container.secrets
    error_message = "The migrate task reads the same secrets, so it loads the same pathways.yaml."
  }
}

run "engine_logs_to_the_logs_submodule_groups" {
  command = plan

  assert {
    condition = (
      module.ecs.engine_container.logConfiguration.options.awslogs-group == output.engine_log_group_name
      && module.ecs.migrate_container.logConfiguration.options.awslogs-group == output.migrate_log_group_name
      && module.ecs.engine_container.logConfiguration.options.awslogs-region == "us-east-1"
    )
    error_message = "Each task logs to its own group, in the provider's region."
  }
}

run "engine_listens_on_each_source_and_the_probe" {
  command = plan

  variables {
    http_sources        = { orders = { port = 8443 } }
    alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = toset([for p in module.ecs.engine_container.portMappings : p.containerPort]) == toset([2575, 8443, 9091])
    error_message = "The engine listens on each MLLP and HTTP source's port and on the probe port."
  }

  assert {
    condition     = keys(module.load_balancers.mllp_target_group_arns) == ["adt"] && keys(module.load_balancers.http_target_group_arns) == ["orders"]
    error_message = "Each source gets its own target group."
  }

  assert {
    condition     = output.nlb_dns_name != null && output.alb_dns_name == "test.example.com"
    error_message = "MLLP and HTTP sources: both load balancers."
  }

  assert {
    condition     = module.security_groups.alb_security_group_id != null && module.security_groups.nlb_security_group_id != null
    error_message = "Each load balancer gets its own security group."
  }
}

run "drain_reaches_the_container_stop_timeout" {
  command = plan

  variables {
    drain_timeout_seconds = 90
  }

  assert {
    condition     = module.ecs.engine_container.stopTimeout == 90
    error_message = "drain_timeout_seconds is the container's stop timeout as well as the deregistration delay."
  }
}

run "migrate_image_moves_the_migrate_task_alone" {
  command = plan

  variables {
    migrate_image = "registry.example.com/integration/project:2@sha256:1111111111111111111111111111111111111111111111111111111111111111"
  }

  assert {
    condition     = module.ecs.migrate_container.image == var.migrate_image && module.ecs.engine_container.image == var.image
    error_message = "migrate_image moves the migrate task and not the engine: that waits for the migrate task to succeed."
  }
}

run "no_sources_no_load_balancers" {
  command = plan

  variables {
    mllp_sources = {}
  }

  assert {
    condition = (
      output.nlb_dns_name == null && output.alb_dns_name == null
      && module.security_groups.nlb_security_group_id == null && module.security_groups.alb_security_group_id == null
    )
    error_message = "With no source there is no load balancer and no load balancer security group."
  }

  assert {
    condition     = [for p in module.ecs.engine_container.portMappings : p.containerPort] == [9091]
    error_message = "With no source the engine listens on the probe port alone."
  }
}

# ---------------------------------------------------------------------------
# The bucket and SFTP, both off by default
# ---------------------------------------------------------------------------

run "no_bucket_and_no_sftp_by_default" {
  command = plan

  assert {
    condition     = length(module.bucket) == 0 && length(module.sftp) == 0
    error_message = "The bucket and the SFTP server are off by default."
  }

  assert {
    condition = (
      output.bucket_name == null && output.bucket_arn == null && output.bucket_access_logs_bucket_name == null
      && output.sftp_server_id == null && output.sftp_endpoint == null && output.sftp_vpc_endpoint_id == null
      && output.sftp_security_group_id == null && output.sftp_log_group_name == null
    )
    error_message = "With neither, their outputs are null."
  }

  assert {
    condition     = !contains([for e in module.ecs.engine_container.environment : e.name], "PATHWAYS_BUCKET")
    error_message = "With no bucket the engine gets no PATHWAYS_BUCKET."
  }
}

run "bucket_reaches_the_engine_through_its_task_role" {
  command = plan

  variables {
    bucket_enabled = true
    environment    = { PATHWAYS_STORAGE = "postgres" }
  }

  assert {
    condition     = length(module.bucket) == 1 && length(module.sftp) == 0
    error_message = "bucket_enabled creates the bucket, and SFTP stays off."
  }

  assert {
    condition = module.ecs.engine_container.environment == [
      { name = "PATHWAYS_BUCKET", value = "pathways-test-00000000000000000000000001" },
      { name = "PATHWAYS_STORAGE", value = "postgres" },
    ]
    error_message = "The engine gets the bucket's name as PATHWAYS_BUCKET, beside the caller's settings."
  }

  assert {
    condition = (
      output.bucket_name == "pathways-test-00000000000000000000000001"
      && output.bucket_arn == "arn:aws:s3:::pathways-test-00000000000000000000000001"
    )
    error_message = "The bucket outputs come from the bucket submodule."
  }

  assert {
    condition = (
      module.bucket[0].task_policy_role_name == output.task_role_name
      && output.task_role_name == "pathways-test-task"
    )
    error_message = "The bucket's policy is for the task role the engine runs as."
  }

  assert {
    condition     = !anytrue([for s in module.ecs.engine_container.secrets : startswith(s.name, "AWS_")]) && !anytrue([for e in module.ecs.engine_container.environment : startswith(e.name, "AWS_")])
    error_message = "No static AWS credential is passed to the engine: it reaches the bucket through its task role."
  }
}

run "sftp_fronts_the_bucket" {
  command = plan

  variables {
    bucket_enabled           = true
    sftp_enabled             = true
    sftp_allowed_cidr_blocks = ["10.30.0.0/24"]
    sftp_users = {
      lab = {
        public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA lab@example.com"]
        home_prefix = "partners/lab"
      }
    }
  }

  assert {
    condition     = length(module.sftp) == 1
    error_message = "sftp_enabled creates the SFTP server."
  }

  assert {
    condition = (
      output.sftp_server_id == "s-00000000000000000"
      && output.sftp_endpoint == "s-00000000000000000.server.transfer.us-east-1.amazonaws.com"
      && output.sftp_log_group_name == "/pathways/test/sftp"
      && output.sftp_security_group_id == "sg-00000000000000000"
    )
    error_message = "The SFTP outputs come from the sftp submodule, and its log group is under the prefix the key's policy lets CloudWatch Logs use."
  }
}

run "sftp_endpoint_defaults_to_the_private_subnets" {
  command = plan

  variables {
    bucket_enabled           = true
    sftp_enabled             = true
    sftp_allowed_cidr_blocks = ["10.30.0.0/24"]
  }

  assert {
    condition     = local.sftp_subnet_ids == var.private_subnet_ids
    error_message = "With no sftp_subnet_ids the endpoint is in the private subnets."
  }
}

# ---------------------------------------------------------------------------
# Root inputs refused
# ---------------------------------------------------------------------------

run "sftp_without_the_bucket_is_refused" {
  command = plan

  variables {
    sftp_enabled             = true
    sftp_allowed_cidr_blocks = ["10.30.0.0/24"]
  }

  expect_failures = [var.sftp_enabled]
}

run "sftp_open_to_anywhere_is_refused" {
  command = plan

  variables {
    bucket_enabled           = true
    sftp_enabled             = true
    sftp_allowed_cidr_blocks = ["0.0.0.0/0"]
  }

  expect_failures = [var.sftp_allowed_cidr_blocks]
}

run "sftp_with_no_allowed_network_is_refused" {
  command = plan

  variables {
    bucket_enabled = true
    sftp_enabled   = true
  }

  expect_failures = [var.sftp_allowed_cidr_blocks]
}

run "bucket_name_from_caller_is_refused" {
  command = plan

  variables {
    bucket_enabled = true
    environment    = { PATHWAYS_BUCKET = "pathways-other" }
  }

  expect_failures = [var.environment]
}

run "bucket_name_in_secrets_is_refused" {
  command = plan

  variables {
    bucket_enabled = true
    secrets        = { PATHWAYS_BUCKET = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/bucket-AbCdEf" }
  }

  expect_failures = [var.secrets]
}

# ---------------------------------------------------------------------------
# Root inputs refused
# ---------------------------------------------------------------------------

run "image_by_tag_alone_is_refused" {
  command = plan

  variables {
    image = "registry.example.com/integration/project:1"
  }

  expect_failures = [var.image]
}

run "migrate_image_by_tag_alone_is_refused" {
  command = plan

  variables {
    migrate_image = "registry.example.com/integration/project:2"
  }

  expect_failures = [var.migrate_image]
}

run "drain_over_fargate_maximum_is_refused" {
  command = plan

  variables {
    drain_timeout_seconds = 121
  }

  expect_failures = [var.drain_timeout_seconds]
}

run "shared_port_is_refused" {
  command = plan

  variables {
    mllp_sources = { adt = { port = 9091 } }
  }

  expect_failures = [var.probe_port]
}

run "database_url_from_caller_is_refused" {
  command = plan

  variables {
    secrets = { PATHWAYS_DATABASE_URL = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/url-AbCdEf" }
  }

  expect_failures = [var.secrets]
}

run "name_in_environment_and_secrets_is_refused" {
  command = plan

  variables {
    environment = { PATHWAYS_KEY = "plain" }
    secrets     = { PATHWAYS_KEY = "arn:aws:secretsmanager:us-east-1:123456789012:secret:test/key-AbCdEf" }
  }

  expect_failures = [var.secrets]
}

run "more_than_five_sources_is_refused" {
  command = plan

  variables {
    mllp_sources = {
      a = { port = 2575 }
      b = { port = 2576 }
      c = { port = 2577 }
      d = { port = 2578 }
      e = { port = 2579 }
      f = { port = 2580 }
    }
  }

  expect_failures = [var.http_sources]
}

run "http_sources_without_a_certificate_are_refused" {
  command = plan

  variables {
    http_sources = { orders = { port = 8443 } }
  }

  expect_failures = [var.alb_certificate_arn]
}

run "database_key_that_is_not_a_kms_key_arn_is_refused" {
  command = plan

  variables {
    database_kms_key_arn = "alias/pathways-test"
  }

  expect_failures = [var.database_kms_key_arn]
}
