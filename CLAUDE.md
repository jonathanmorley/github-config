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
