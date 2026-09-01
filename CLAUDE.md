# CLAUDE.md — Agent Instructions

Guidance for AI agents and contributors working on this repository.

## Layout

- `*.tf` — OpenTofu configuration (HCL) managed by the GitHub provider
  (`registry.terraform.io/jonathanmorley/github` — a patched fork of
  `integrations/github`).
- `repos.tf` — the per-repository resource definitions and their `import` blocks.
- `scripts/check-imports.sh` — a static check enforcing the import rule below.
- `.github/workflows/terraform.yml` — plan/apply CI; runs `scripts/check-imports.sh`.
- `.github/workflows/drift.yml` — scheduled drift detection.

## Rule: every resource needs an `import` block

Every managed GitHub object in this config pre-exists on GitHub, so each
`resource` block MUST have a matching `import` block that adopts the existing
object into OpenTofu state. This avoids Terraform creating objects out-of-band
(from which drift and destructive applies follow), and keeps state consistent
with what is actually configured on GitHub.

- The `import` block must target the same address as the resource.
- For `for_each`/`count` resources, the import's `to` uses the indexed address
  (e.g. `github_foo.this[each.value]`); the plain base address
  (e.g. `github_foo.this`) is what must be matched.
- The import `id` is the repository name (`each.value`) for repo-scoped
  resources.

This is enforced deterministically by `scripts/check-imports.sh`, which
`terraform.yml` runs on every plan. Keep it green.

**SHA pinning:** when managing `github_actions_repository_permissions` with
`sha_pinning_required`, also set `allowed_actions = "all"` explicitly. SHA
pinning only applies when `allowed_actions` is `all` (it is ignored for
`local_only` / `selected`), so set both so the enforcement is meaningful and
self-documenting.

**Immutable releases:** `github_repository_immutable_releases` enforces
GitHub's "Enable release immutability" so release content cannot be modified
or deleted. It is a repo-scoped resource with a matching `import` block; set
`enabled = true` to enforce it on every managed repo.

**Branch protection:** `github_repository_ruleset` protects the default branch
of every applicable repo (see `protected_repos` in `repos.tf`). The resource
`for_each` iterates `local.protected_repos`, which excludes forks, archived
repos, and repos listed in `ruleset_excluded_repos` (already-protected repos and
private repos — rulesets are a paid feature for private repos on the free plan,
GitHub 403s it). The ruleset applies to `~DEFAULT_BRANCH` via
`conditions.ref_name.include`, requires a PR with 0 approvals
(`pull_request { required_approving_review_count = 0 }`), conversation
resolution, linear history and signed commits, and blocks branch deletion.
Force pushes are blocked by default (a ruleset only permits them when a
`non_fast_forward` rule exists — never add one). Rulesets cannot express the
check-agnostic "require branches to be up to date" gate (GitHub rejects an
empty `required_status_checks` list), so that rule is intentionally dropped;
classic branch protection's `strict` + empty `contexts` could express it, but
rulesets are the uniform modern mechanism. The `pull_request` block must be
present, or direct pushes remain allowed.

**Branch protection lifecycle (bootstrap then import):** these rules are
brand-new, so the first apply must CREATE them through Terraform. During this
bootstrap phase the resource is annotated `# no-import` and has no import
block. Follow-up change: once the rules exist on GitHub **and** the provider
fork has released the `github_repository_rulesets` data source, add the
matching `import` block (`for_each = toset(local.protected_repos)`, `to =
github_repository_ruleset.default[each.value]`) with `id =
"${each.value}:${[for rs in data.github_repository_rulesets.this[each.value].rulesets : rs.id if rs.name == var.ruleset_name][0]}"`,
and remove the `# no-import` annotation so ephemeral-state runs adopt the
existing rules instead of recreating them. Never create these rules with the
raw GitHub API — they must only ever be created or modified through the
Terraform deployment. Note: during the bootstrap phase every `tofu apply`
would create another duplicate ruleset (there is no state to adopt from), so
the Phase 1 ruleset PR must be followed promptly by the Phase 2 import PR, and
drift runs (which only plan, never apply) are safe in the meantime.

**Archived repos:** `managed_repos` filters out archived repos (via
`data.github_repository.managed[repo].archived`), so every resource `for_each`
below skips them. When a repo is archived, the next ephemeral-state run simply
forgets it — nothing is deleted. The raw discovery set (`all_repos`) still
includes archived repos so their status can be learned.

**Escape hatch:** if a resource is genuinely create-only (a brand-new object
that does not exist on GitHub yet), you may annotate the `resource` line with a
trailing `# no-import` comment to exempt it.

## Git conventions

- Work in an isolated worktree under the repo-root `.worktrees/` directory.
- Keep commits and PRs small and focused on a single concern.
- Label PRs with `ai:autofix`.

## Validation

Before finishing, run:

```bash
scripts/check-imports.sh
tofu fmt -check -recursive
tofu validate   # after `tofu init`
tofu plan       # preview
```

Note: `tofu` is available via `nix run nixpkgs#opentofu -- ...`.
