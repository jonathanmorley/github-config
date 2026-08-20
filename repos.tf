data "http" "repos" {
  url = "https://api.github.com/orgs/jonathanmorley/repos?per_page=100&type=all"

  request_headers = {
    Accept        = "application/vnd.github+json"
    Authorization = "Bearer ${var.github_token}"
  }
}

locals {
  all_repos = jsondecode(data.http.repos.response_body)
  managed_repos = [
    for repo in local.all_repos :
    repo.name
    if !contains(var.excluded_repos, repo.name)
  ]
}

resource "github_repository" "managed" {
  for_each = toset(local.managed_repos)

  name = each.value

  # Auto-merge settings
  allow_auto_merge       = var.default_settings.allow_auto_merge
  delete_branch_on_merge = var.default_settings.delete_branch_on_merge

  # Feature flags
  has_issues   = var.default_settings.has_issues
  has_projects = var.default_settings.has_projects
  has_wiki     = var.default_settings.has_wiki

  # Merge strategies
  allow_merge_commit = var.default_settings.allow_merge_commit
  allow_squash_merge = var.default_settings.allow_squash_merge
  allow_rebase_merge = var.default_settings.allow_rebase_merge

  # Prevent Terraform from deleting repos and ignore fields we don't manage
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      description,
    ]
  }
}
