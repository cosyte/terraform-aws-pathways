terraform {
  # 1.11 brought write-only arguments, which keep the database password out of the state.
  required_version = ">= 1.11"

  # The root holds no resource of its own: the submodules under modules/ inherit these providers
  # from it, and each declares the same constraints for the ones it uses. tflint's
  # terraform_unused_required_providers counts only the root's own resources, so it would have
  # these removed; the root keeps them, because they are the constraints a caller reads, and
  # because terraform test hands a mocked provider only to a root module that requires it. The
  # README lists this accepted finding.
  required_providers {
    # tflint-ignore: terraform_unused_required_providers
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    # The ephemeral random_password of modules/database, which is never written to the plan or the
    # state.
    # tflint-ignore: terraform_unused_required_providers
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7, < 4.0"
    }
  }
}
