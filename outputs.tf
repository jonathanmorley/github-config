output "managed_repos" {
  description = "List of repos being managed"
  value       = local.managed_repos
}

output "repo_count" {
  description = "Number of repos being managed"
  value       = length(local.managed_repos)
}

output "excluded_repos" {
  description = "List of repos excluded from management"
  value       = var.excluded_repos
}
