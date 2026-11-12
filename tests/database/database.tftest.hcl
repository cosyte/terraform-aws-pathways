# Plan-only tests of modules/database on its own, against a mocked aws provider. The random provider
# is real: it runs locally and calls nothing. Every value is synthetic: the documentation account id
# 123456789012, ids of zeros and counting digits, and names on example.com.

mock_provider "aws" {
  override_during = plan

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      id  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address = "pathways-test.example.com"
    }
  }
}

variables {
  name               = "test"
  subnet_ids         = ["subnet-00000000000000001", "subnet-00000000000000002"]
  security_group_ids = ["sg-00000000000000001"]
  kms_key_arn        = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
}

run "database_is_encrypted_private_and_forces_tls" {
  command = plan

  module {
    source = "./modules/database"
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted && aws_db_instance.this.kms_key_id == var.kms_key_arn
    error_message = "The database's storage is encrypted under kms_key_arn."
  }

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "The database is not publicly accessible."
  }

  assert {
    condition     = anytrue([for p in aws_db_parameter_group.this.parameter : p.name == "rds.force_ssl" && p.value == "1"])
    error_message = "The database refuses connections without TLS (rds.force_ssl = 1)."
  }

  assert {
    condition     = aws_db_instance.this.engine == "postgres" && aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot
    error_message = "The database is PostgreSQL, protected from deletion, with a final snapshot."
  }

  assert {
    condition     = aws_db_instance.this.performance_insights_enabled == false
    error_message = "Performance Insights keeps statement text: it stays off."
  }

  assert {
    condition     = aws_db_instance.this.vpc_security_group_ids == toset(["sg-00000000000000001"])
    error_message = "Only the security groups given apply to the database."
  }

  assert {
    condition     = aws_db_subnet_group.this.subnet_ids == toset(var.subnet_ids)
    error_message = "The database runs in the subnets given."
  }
}

run "secret_holds_the_url_under_the_key" {
  command = plan

  module {
    source = "./modules/database"
  }

  assert {
    condition     = aws_secretsmanager_secret.url.kms_key_id == var.kms_key_arn && aws_secretsmanager_secret.url.name == "pathways/test/database-url"
    error_message = "The connection URL secret is pathways/<name>/database-url, encrypted under kms_key_arn."
  }

  assert {
    condition     = output.url_secret_arn == "arn:aws:secretsmanager:us-east-1:123456789012:secret:pathways/test/database-url-AbCdEf"
    error_message = "url_secret_arn is the secret's ARN."
  }

  assert {
    condition     = output.address == "pathways-test.example.com"
    error_message = "address is the instance's hostname."
  }
}

run "raising_password_version_rotates_password_and_url" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    password_version = 2
  }

  assert {
    condition     = aws_db_instance.this.password_wo_version == 2
    error_message = "Raising password_version sets a new password on the database."
  }

  assert {
    condition     = aws_secretsmanager_secret_version.url.secret_string_wo_version == 2
    error_message = "Raising password_version writes a new connection URL to the secret in the same run."
  }
}

run "storage_key_from_caller_outlives_the_secret_key" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    storage_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  }

  assert {
    condition = (
      aws_db_instance.this.storage_encrypted
      && aws_db_instance.this.kms_key_id == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
      && output.storage_kms_key_arn == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    )
    error_message = "With storage_kms_key_arn set, the database and its snapshots are encrypted under it."
  }

  assert {
    condition     = aws_secretsmanager_secret.url.kms_key_id == var.kms_key_arn
    error_message = "The secret stays under kms_key_arn."
  }
}

run "storage_key_that_is_not_a_kms_key_arn_is_refused" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    storage_kms_key_arn = "alias/pathways-test"
  }

  expect_failures = [var.storage_kms_key_arn]
}

run "one_subnet_is_refused" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    subnet_ids = ["subnet-00000000000000001"]
  }

  expect_failures = [var.subnet_ids]
}

run "no_security_group_is_refused" {
  command = plan

  module {
    source = "./modules/database"
  }

  variables {
    security_group_ids = []
  }

  expect_failures = [var.security_group_ids]
}
