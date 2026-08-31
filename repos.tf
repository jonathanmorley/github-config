data "github_repositories" "public" {
  query = "user:jonathanmorley is:public"
}

data "github_repositories" "private" {
  query = "user:jonathanmorley is:private"
}

locals {
  public_repos = [
    for repo in distinct(compact(data.github_repositories.public.names)) :
    repo
    if !contains(var.excluded_repos, repo)
  ]

  private_repos = [
    for repo in distinct(compact(data.github_repositories.private.names)) :
    repo
    if !contains(var.excluded_repos, repo)
  ]

  managed_repos = concat(local.public_repos, local.private_repos)
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
}

import {
  for_each = toset(local.managed_repos)
  id       = each.value
  to       = github_actions_repository_permissions.this[each.value]
}

# Require all actions and reusable workflows to be pinned to a full-length
# commit SHA on every managed repo
resource "github_actions_repository_permissions" "this" {
  for_each = toset(local.managed_repos)

  repository           = each.value
  sha_pinning_required = true
}
