# GitHub Config

Terraform-managed configuration for all `jonathanmorley/*` repositories.

## What It Manages

- Repository settings (auto-merge, features, merge strategies)
- Drift detection via daily scheduled runs
- Automated enforcement via PR merges

## Usage

### Local Development

```bash
terraform init
terraform plan    # Preview changes
terraform apply   # Apply changes
```

### How It Works

1. **Discovery:** Automatically finds all repos in the `jonathanmorley` namespace
2. **Defaults:** Applies uniform settings from `variables.tf`
3. **Exclusions:** Skip repos via `excluded_repos` variable
4. **Overrides:** Per-repo exceptions via `repo_overrides` variable (future)

## Authentication

This repo uses [Octo STS](https://github.com/chainguard-dev/octo-sts) for short-lived GitHub credentials. The trust policy is at `jonathanmorley/.github/.github/chainguard/terraform.sts.yaml`.

State is stored in Terraform Cloud. GHA authenticates via `TF_TOKEN_app_terraform_io`.

## Adding a New Repo

New repos are automatically discovered. No action needed.

## Excluding a Repo

Add the repo name to the `excluded_repos` variable in `variables.tf`:

```hcl
variable "excluded_repos" {
  default = ["repo-to-skip"]
}
```

## Adding Per-Repo Overrides

Use the `repo_overrides` variable (coming soon):

```hcl
variable "repo_overrides" {
  default = {
    "special-repo" = {
      allow_auto_merge = false
    }
  }
}
```
