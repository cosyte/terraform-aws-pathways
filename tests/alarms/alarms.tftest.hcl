# Plan-only tests of modules/alarms on its own, against a mocked aws provider. Every value is
# synthetic: the documentation account id 123456789012, ids of zeros, and a topic and a role named
# for a test.

mock_provider "aws" {
  override_during = plan

  # A mocked policy document still has to be valid JSON: the role policy reads it.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      id  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/health-token-AbCdEf"
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/health-token-AbCdEf"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/metrics"
    }
  }
}

variables {
  name             = "test"
  log_group_prefix = "/pathways/test"
  kms_key_arn      = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  task_role_name   = "pathways-test-task"
  sns_topic_arn    = "arn:aws:sns:us-east-1:123456789012:pathways-test-alarms"
}

# ---------------------------------------------------------------------------
# The health token
# ---------------------------------------------------------------------------

run "token_is_in_an_encrypted_secret_and_never_in_the_plan" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  assert {
    condition = (
      aws_secretsmanager_secret.health_token.name == "pathways/test/health-token"
      && aws_secretsmanager_secret.health_token.kms_key_id == var.kms_key_arn
    )
    error_message = "The token's secret is pathways/<name>/health-token, encrypted under the key given."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.health_token.secret_string_wo_version == 1
    error_message = "The token is written write-only, in secret_string_wo, which the plan and the state never hold: only its version is kept."
  }

  assert {
    condition     = output.health_token_secret_arn == "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/health-token-AbCdEf" && output.health_token_variable == "PATHWAYS_HEALTH_TOKEN"
    error_message = "The outputs name the secret by its ARN and the variable the engine reads, never the token."
  }
}

run "token_version_writes_a_new_token" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  variables {
    health_token_version = 2
  }

  assert {
    condition     = aws_secretsmanager_secret_version.health_token.secret_string_wo_version == 2
    error_message = "health_token_version moves the write-only version, which writes a new token."
  }
}

# ---------------------------------------------------------------------------
# The collector's configuration
# ---------------------------------------------------------------------------

run "collector_scrapes_the_health_port_over_loopback_with_the_token" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  assert {
    condition = yamldecode(output.collector_config).receivers.prometheus.config.scrape_configs[0] == {
      job_name        = "pathways"
      scrape_interval = "30s"
      scrape_timeout  = "10s"
      metrics_path    = "/metrics"
      scheme          = "http"
      authorization   = { type = "Bearer", credentials = "$${env:PATHWAYS_HEALTH_TOKEN}" }
      static_configs  = [{ targets = ["127.0.0.1:9090"] }]
    }
    error_message = "The collector scrapes http://127.0.0.1:9090/metrics every 30 seconds with the token it reads from PATHWAYS_HEALTH_TOKEN."
  }
}

run "health_port_moves_the_scrape" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  variables {
    health_port = 9443
  }

  assert {
    condition     = yamldecode(output.collector_config).receivers.prometheus.config.scrape_configs[0].static_configs[0].targets == ["127.0.0.1:9443"]
    error_message = "health_port is the port the collector scrapes."
  }
}

run "collector_keeps_four_families_and_no_channel_or_destination" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  assert {
    condition = (
      strcontains(yamldecode(output.collector_config).processors["filter/pathways"].metrics.metric[0], "name == \"pathways_store_up\"")
      && strcontains(yamldecode(output.collector_config).processors["filter/pathways"].metrics.metric[0], "name == \"pathways_oldest_pending_age_seconds\"")
      && strcontains(yamldecode(output.collector_config).processors["filter/pathways"].metrics.metric[0], "name == \"pathways_messages_refused_total\"")
      && strcontains(yamldecode(output.collector_config).processors["filter/pathways"].metrics.metric[0], "name == \"pathways_settled_destinations_total\"")
      && startswith(yamldecode(output.collector_config).processors["filter/pathways"].metrics.metric[0], "not (")
      && !strcontains(yamldecode(output.collector_config).processors["filter/pathways"].metrics.metric[0], "queue_depth")
    )
    error_message = "The filter drops every metric but the four families the alarms read."
  }

  assert {
    condition     = strcontains(yamldecode(output.collector_config).processors["filter/pathways"].metrics.datapoint[0], "attributes[\"outcome\"] != \"failed\"")
    error_message = "Of the settlements, only those that failed are kept."
  }

  assert {
    condition = alltrue([
      for t in yamldecode(output.collector_config).processors["metricstransform/pathways"].transforms :
      t.operations[1].action == "aggregate_labels" && t.operations[1].label_set == ["Deployment"]
      && t.operations[0].action == "add_label" && t.operations[0].new_label == "Deployment" && t.operations[0].new_value == "test"
    ])
    error_message = "Every family keeps only the Deployment label: channel, destination and outcome are folded away."
  }

  assert {
    condition     = join(",", [for t in yamldecode(output.collector_config).processors["metricstransform/pathways"].transforms : "${t.new_name}:${t.operations[1].aggregation_type}"]) == "pathways_messages_refused_total:sum,pathways_oldest_pending_age_seconds:max,pathways_settled_destinations_total:sum,pathways_store_up:min"
    error_message = "store_up folds to its minimum, the oldest pending age to its maximum, and the two counters to their sum."
  }

  assert {
    condition = (
      yamldecode(output.collector_config).exporters.awsemf.namespace == "Pathways"
      && yamldecode(output.collector_config).exporters.awsemf.log_group_name == "/pathways/test/metrics"
      && yamldecode(output.collector_config).exporters.awsemf.dimension_rollup_option == "NoDimensionRollup"
      && yamldecode(output.collector_config).exporters.awsemf.metric_declarations[0].dimensions == [["Deployment"]]
    )
    error_message = "The metrics go to the Pathways namespace through the metrics log group, with the one dimension Deployment."
  }

  assert {
    condition     = yamldecode(output.collector_config).service.pipelines.metrics.processors == ["filter/pathways", "metricstransform/pathways", "batch"]
    error_message = "The filter runs before the labels are folded, so the settlements are filtered by outcome first."
  }
}

# ---------------------------------------------------------------------------
# The log group and the task role
# ---------------------------------------------------------------------------

run "metrics_log_group_is_encrypted_and_the_task_role_writes_only_it" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  assert {
    condition = (
      aws_cloudwatch_log_group.metrics.name == "/pathways/test/metrics"
      && aws_cloudwatch_log_group.metrics.kms_key_id == var.kms_key_arn
      && aws_cloudwatch_log_group.metrics.retention_in_days == 365
    )
    error_message = "The metrics log group is <prefix>/metrics, encrypted under the key, kept for log_retention_days."
  }

  assert {
    condition = (
      length(data.aws_iam_policy_document.task.statement) == 1
      && toset(data.aws_iam_policy_document.task.statement[0].actions) == toset(["logs:CreateLogStream", "logs:PutLogEvents"])
      && toset(data.aws_iam_policy_document.task.statement[0].resources) == toset(["arn:aws:logs:us-east-1:123456789012:log-group:/pathways/test/metrics:*"])
    )
    error_message = "The task role may create streams in and write to the metrics log group, and nothing else."
  }

  assert {
    condition     = aws_iam_role_policy.task.role == "pathways-test-task"
    error_message = "The policy is attached to the task role given."
  }
}

# ---------------------------------------------------------------------------
# The four alarms
# ---------------------------------------------------------------------------

run "four_alarms_with_their_defaults_publish_to_the_topic" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  assert {
    condition = alltrue([
      for a in [
        aws_cloudwatch_metric_alarm.store_down,
        aws_cloudwatch_metric_alarm.oldest_pending_age,
        aws_cloudwatch_metric_alarm.refused_messages,
        aws_cloudwatch_metric_alarm.settled_failed,
      ] :
      a.namespace == "Pathways" && a.dimensions == tomap({ Deployment = "test" })
      && a.alarm_actions == toset([var.sns_topic_arn]) && a.ok_actions == toset([var.sns_topic_arn])
    ])
    error_message = "Each alarm reads the Pathways namespace for this deployment and publishes to the topic on alarm and on OK."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.store_down.metric_name == "pathways_store_up"
      && aws_cloudwatch_metric_alarm.store_down.statistic == "Minimum"
      && aws_cloudwatch_metric_alarm.store_down.comparison_operator == "LessThanThreshold"
      && aws_cloudwatch_metric_alarm.store_down.threshold == 1
      && aws_cloudwatch_metric_alarm.store_down.period == 60
      && aws_cloudwatch_metric_alarm.store_down.evaluation_periods == 2
      && aws_cloudwatch_metric_alarm.store_down.treat_missing_data == "breaching"
    )
    error_message = "Store down: pathways_store_up below 1 for 2 minutes, and a missing minute counts."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.oldest_pending_age.metric_name == "pathways_oldest_pending_age_seconds"
      && aws_cloudwatch_metric_alarm.oldest_pending_age.statistic == "Maximum"
      && aws_cloudwatch_metric_alarm.oldest_pending_age.comparison_operator == "GreaterThanThreshold"
      && aws_cloudwatch_metric_alarm.oldest_pending_age.threshold == 600
      && aws_cloudwatch_metric_alarm.oldest_pending_age.evaluation_periods == 5
      && aws_cloudwatch_metric_alarm.oldest_pending_age.treat_missing_data == "notBreaching"
    )
    error_message = "Oldest pending age: above 600 seconds for 5 minutes."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.refused_messages.metric_name == "pathways_messages_refused_total"
      && aws_cloudwatch_metric_alarm.refused_messages.statistic == "Sum"
      && aws_cloudwatch_metric_alarm.refused_messages.period == 900
      && aws_cloudwatch_metric_alarm.refused_messages.threshold == 0
      && aws_cloudwatch_metric_alarm.refused_messages.comparison_operator == "GreaterThanThreshold"
    )
    error_message = "Refused messages: more than 0 in 15 minutes."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.settled_failed.metric_name == "pathways_settled_destinations_total"
      && aws_cloudwatch_metric_alarm.settled_failed.statistic == "Sum"
      && aws_cloudwatch_metric_alarm.settled_failed.period == 900
      && aws_cloudwatch_metric_alarm.settled_failed.threshold == 0
      && aws_cloudwatch_metric_alarm.settled_failed.comparison_operator == "GreaterThanThreshold"
    )
    error_message = "Settled destinations failing: more than 0 failed settlements in 15 minutes."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.store_down.alarm_name == "pathways-test-store-down" && aws_cloudwatch_metric_alarm.settled_failed.alarm_name == "pathways-test-settled-failed"
    error_message = "The alarms are named pathways-<name>-<alarm>."
  }
}

run "thresholds_are_the_callers" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  variables {
    store_down_minutes         = 5
    oldest_pending_age_seconds = 1800
    refused_messages_threshold = 10
    settled_failed_threshold   = 3
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.store_down.evaluation_periods == 5
      && aws_cloudwatch_metric_alarm.store_down.datapoints_to_alarm == 5
      && aws_cloudwatch_metric_alarm.oldest_pending_age.threshold == 1800
      && aws_cloudwatch_metric_alarm.refused_messages.threshold == 10
      && aws_cloudwatch_metric_alarm.settled_failed.threshold == 3
    )
    error_message = "Each threshold is an input."
  }
}

run "topic_that_is_not_an_sns_arn_is_refused" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  variables {
    sns_topic_arn = "pathways-test-alarms"
  }

  expect_failures = [var.sns_topic_arn]
}

run "fractional_threshold_is_refused" {
  command = plan

  module {
    source = "./modules/alarms"
  }

  variables {
    refused_messages_threshold = 0.5
  }

  expect_failures = [var.refused_messages_threshold]
}
