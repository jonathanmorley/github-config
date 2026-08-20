variable "default_settings" {
  description = "Default settings applied to all managed repos"
  type = object({
    allow_auto_merge       = bool
    delete_branch_on_merge = bool
    has_issues             = bool
    has_projects           = bool
    has_wiki               = bool
    allow_merge_commit     = bool
    allow_squash_merge     = bool
    allow_rebase_merge     = bool
  })
  default = {
    allow_auto_merge       = true
    delete_branch_on_merge = false
    has_issues             = true
    has_projects           = true
    has_wiki               = false
    allow_merge_commit     = true
    allow_squash_merge     = true
    allow_rebase_merge     = true
  }
}

variable "excluded_repos" {
  description = "List of repo names to exclude from management"
  type        = list(string)
  default     = []
}

variable "github_token" {
  description = "GitHub token for API authentication (used for repo discovery)"
  type        = string
  sensitive   = true
}

variable "repo_overrides" {
  description = "Per-repo setting overrides (repo name -> settings map)"
  type        = map(map(any))
  default     = {}
}
