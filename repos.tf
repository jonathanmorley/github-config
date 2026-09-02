data "github_repositories" "public" {
  query = "user:jonathanmorley is:public"
}

data "github_repositories" "private" {
  query = "user:jonathanmorley is:private"
}

# Repos discovered by the namespace search, before per-repo filtering. We keep
# these raw so the data source can learn each repo's archived/fork status and
# default branch, and the filtered locals below decide what gets managed.
locals {
  public_candidates = [
    for repo in distinct(compact(data.github_repositories.public.names)) :
    repo
    if !contains(var.excluded_repos, repo)
  ]

  private_candidates = [
    for repo in distinct(compact(data.github_repositories.private.names)) :
    repo
    if !contains(var.excluded_repos, repo)
  ]

  all_repos = concat(local.public_candidates, local.private_candidates)
}

# Per-repo facts (default branch, fork status, archived status, node id).
# Covers every candidate repo so the filtered locals can decide what is
# actively managed.
data "github_repository" "managed" {
  for_each = toset(local.all_repos)

  name = each.value
}

locals {
  # Actively managed repos. Archived repos drop out of every `for_each` below,
  # so they are no longer managed by this config at all. (Removing an archived
  # repo from config only forgets it on the next ephemeral-state run — it does
  # not delete anything.)
  public_repos = [
    for repo in local.public_candidates :
    repo
    if !data.github_repository.managed[repo].archived
  ]

  private_repos = [
    for repo in local.private_candidates :
    repo
    if !data.github_repository.managed[repo].archived
  ]

  managed_repos = concat(local.public_repos, local.private_repos)

  # Repos that get default-branch protection: every managed repo except forks
  # (they need direct-push workflows to track upstreams) and repos excluded
  # via `ruleset_excluded_repos`.
  protected_repos = [
    for repo in local.managed_repos :
    repo
    if !data.github_repository.managed[repo].fork &&
    !contains(var.ruleset_excluded_repos, repo)
  ]
}

import {
  for_each = toset(local.public_repos)
  id       = each.value
  to       = github_repository.public[each.value]
}

import {
  for_each = toset(local.private_repos)
  id       = each.value
  to       = github_repository.private[each.value]
}

import {
  for_each = toset(local.managed_repos)
  id       = each.value
  to       = github_repository_vulnerability_alerts.this[each.value]
}

import {
  for_each = toset(local.managed_repos)
  id       = each.value
  to       = github_repository_dependabot_security_updates.this[each.value]
}

resource "github_repository" "public" {
  for_each = toset(local.public_repos)

  name = each.value

  # Auto-merge settings
  allow_auto_merge       = var.public_default_settings.allow_auto_merge
  delete_branch_on_merge = var.public_default_settings.delete_branch_on_merge

  # Feature flags
  has_issues   = var.public_default_settings.has_issues
  has_projects = var.public_default_settings.has_projects
  has_wiki     = var.public_default_settings.has_wiki

  # Merge strategies
  allow_merge_commit = var.public_default_settings.allow_merge_commit
  allow_squash_merge = var.public_default_settings.allow_squash_merge
  allow_rebase_merge = var.public_default_settings.allow_rebase_merge

  # Prevent Terraform from deleting repos and ignore fields we don't manage
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      description,
    ]
  }
}

resource "github_repository" "private" {
  for_each = toset(local.private_repos)

  name = each.value

  # Auto-merge settings (disabled for private repos — GitHub doesn't support it)
  allow_auto_merge       = var.private_default_settings.allow_auto_merge
  delete_branch_on_merge = var.private_default_settings.delete_branch_on_merge

  # Feature flags
  has_issues   = var.private_default_settings.has_issues
  has_projects = var.private_default_settings.has_projects
  has_wiki     = var.private_default_settings.has_wiki

  # Merge strategies
  allow_merge_commit = var.private_default_settings.allow_merge_commit
  allow_squash_merge = var.private_default_settings.allow_squash_merge
  allow_rebase_merge = var.private_default_settings.allow_rebase_merge

  # Prevent Terraform from deleting repos and ignore fields we don't manage
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      description,
    ]
  }
}

# Dependabot alerts and security updates are free on personal accounts,
# including private repos
resource "github_repository_vulnerability_alerts" "this" {
  for_each   = toset(local.managed_repos)
  repository = each.value
  enabled    = true
}

resource "github_repository_dependabot_security_updates" "this" {
  for_each   = toset(local.managed_repos)
  repository = each.value
  enabled    = true

  # GitHub requires vulnerability alerts to be enabled before automated
  # security fixes can be configured. Without this explicit dependency,
  # OpenTofu runs these two for_each resources in parallel and the PUT to
  # automated-security-fixes can race the alerts enablement (422).
  depends_on = [github_repository_vulnerability_alerts.this]
}

import {
  for_each = toset(local.managed_repos)
  id       = each.value
  to       = github_actions_repository_permissions.this[each.value]
}

# Require all actions and reusable workflows to be pinned to a full-length
# commit SHA on every managed repo. SHA pinning is only applicable when
# `allowed_actions` is `all`, so set both explicitly.
resource "github_actions_repository_permissions" "this" {
  for_each = toset(local.managed_repos)

  repository           = each.value
  allowed_actions      = "all"
  sha_pinning_required = true
}

import {
  for_each = toset(local.managed_repos)
  id       = each.value
  to       = github_repository_immutable_releases.this[each.value]
}

# Enforce immutable releases ("Enable release immutability") on every managed
# repo so the content of existing and future releases cannot be modified or
# deleted, strengthening release supply-chain integrity.
resource "github_repository_immutable_releases" "this" {
  for_each = toset(local.managed_repos)

  repository = each.value
  enabled    = true
}

# Protect the default branch of every applicable managed repo (forks and
# excluded repos — see `ruleset_excluded_repos`) with a branch ruleset:
#
#   - Require a pull request before merging, with 0 required approvals
#     (repos are solo-maintained; merging still goes through a PR)
#   - Require conversation resolution
#   - Require linear history (blocks merge commits on the default branch)
#   - Require signed commits
#   - Block branch deletion
#   - Block force pushes (`non_fast_forward = true`; a ruleset WITHOUT this
#     rule actually ALLOWS force pushes, so it must be set explicitly)
#   - Restrict PR merge methods to squash and rebase (consistent with
#     require_linear_history — no merge commits)
#   - Enforced for everyone (no bypass actors)
#
# Unlike classic branch protection, a ruleset cannot express the
# check-agnostic "require branches to be up to date" gate (GitHub rejects an
# empty `required_status_checks` list), so that rule is dropped. See CLAUDE.md.
#
# Each ruleset is discovered at plan time by `data.github_repository_rulesets`
# and adopted (not created) via the matching import block, because the ruleset's
# numeric id is GitHub-assigned (unknown until it exists). An import block here
# prevents re-apply from POST-creating a duplicate ruleset. Never create or
# modify these rules with the raw GitHub API.
data "github_repository_rulesets" "this" {
  for_each   = toset(local.protected_repos)
  repository = each.value
}

import {
  for_each = toset(local.protected_repos)
  id = "${each.value}:${[
    for rs in data.github_repository_rulesets.this[each.value].rulesets :
    rs.id if rs.name == var.ruleset_name
  ][0]}"
  to = github_repository_ruleset.default[each.value]
}

resource "github_repository_ruleset" "default" {
  for_each = toset(local.protected_repos)

  name        = var.ruleset_name
  repository  = data.github_repository.managed[each.value].name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    non_fast_forward        = true # Block force pushes
    required_linear_history = true
    required_signatures     = true
    deletion                = true

    pull_request {
      required_approving_review_count   = 0
      required_review_thread_resolution = true
      allowed_merge_methods             = ["squash", "rebase"] # match require_linear_history: no merge commits
    }
  }
}
