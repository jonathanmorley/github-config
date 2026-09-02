variable "public_default_settings" {
  description = "Default settings applied to public repos"
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
    delete_branch_on_merge = true
    has_issues             = true
    has_projects           = true
    has_wiki               = false
    allow_merge_commit     = true
    allow_squash_merge     = true
    allow_rebase_merge     = true
  }
}

variable "private_default_settings" {
  description = "Default settings applied to private repos (auto-merge disabled — GitHub doesn't support it for private repos)"
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
    allow_auto_merge       = false
    delete_branch_on_merge = true
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

variable "ruleset_excluded_repos" {
  description = <<-EOT
    List of repo names excluded from default-branch protection. Reasons:
    - Already protect their default branch via their own rulesets: asdf-mono,
      asdf-pnpm, nixpkgs, oktaws
    - Archived (excluded from management but kept listed for safety): workup
    - Private repos — repository rulesets are a paid feature on GitHub's
      free plan (GitHub returns 403 "Upgrade to GitHub Pro or make this
      repository public to enable this feature."): cars, floorplans,
      nixpkgs-sanitized-preview, notes
  EOT
  type        = list(string)
  default     = ["asdf-mono", "asdf-pnpm", "nixpkgs", "oktaws", "workup", "cars", "floorplans", "nixpkgs-sanitized-preview", "notes", "tag-trigger-test"]
}

variable "ruleset_name" {
  description = "Name of the default-branch ruleset created on every protected repo"
  type        = string
  default     = "Default branch protection"
}

variable "repo_overrides" {
  description = "Per-repo setting overrides (repo name -> settings map)"
  type        = map(map(any))
  default     = {}
}
