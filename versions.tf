terraform {
  # 1.11 brought write-only arguments, which keep the database password out of the state.
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    # The ephemeral random_password, which is never written to the plan or the state.
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7, < 4.0"
    }
  }
}
