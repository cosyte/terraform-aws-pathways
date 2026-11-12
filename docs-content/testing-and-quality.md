---
id: testing-and-quality
title: Testing and quality
sidebar_label: Testing and quality
description: "How the module is tested without an AWS account: terraform test against mocked providers, validate, tflint, trivy, and what none of them can catch."
---

# Testing and quality

Every check below runs on every pull request, each as its own CI job, and none needs AWS credentials:
no job assumes a role or reads a secret, and nothing plans against or applies to a real account.

## What we check

- **`terraform test`, plan only, against a mocked `aws` provider**, over one directory per subject:
  `tests/composition` for the root module, and `tests/<name>` for each submodule. Each run block
  plans with a set of inputs and asserts what the plan holds: the wiring between submodules, the
  settings that keep data private and encrypted, and that a wrong input is refused. The script
  refuses a run block that does not plan and a test file that does not mock `aws`, takes every AWS
  credential away from Terraform first, and refuses a submodule without its test directory.
- **`terraform validate`** of the root, each submodule and each example, after
  `terraform init -backend=false`, and a check of the layout: the root holds only the composition,
  and each submodule its own `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` and README.
- **tflint** with the AWS ruleset, and **trivy config** at HIGH and CRITICAL. An accepted trivy
  finding is an inline ignore with its reason, listed in the README.
- **`terraform fmt -check`** over every file, and **actionlint** over every workflow.
- **The docs**: `scripts/docs.sh` regenerates the reference pages and each example's files from the
  code and fails when they differ from what is committed, or when an example has no page.
- **No em or en dash** in any tracked file, pull request title, body or commit message.

## What they cannot catch

- **What AWS refuses at apply.** A mocked provider accepts any value its schema allows, so a
  combination AWS rejects (a memory size Fargate does not offer for the CPU chosen, a name already
  taken in the account) passes every test here and fails at apply.
- **How the deployed engine behaves**: whether it turns healthy, reaches its database or drains in
  time. That depends on your image and your network.
- **What it costs.** No check here reads a price.

We have not applied the module to a real account yet; until we have, plan it in yours and read the
plan before you apply.

## Run the checks yourself

From a clone, on the versions `mise.toml` pins:

```sh
mise exec terraform -- terraform fmt -check -recursive
scripts/check-no-emdash.sh
mise exec terraform-docs -- scripts/docs.sh
mise exec terraform -- scripts/validate.sh
mise exec trivy -- scripts/policy.sh
mise exec actionlint -- actionlint
mise exec terraform -- scripts/test.sh
```

## Current numbers

The numbers for this section are measured on `main` at each release and filled in when the release
is built. They are never typed by hand.
