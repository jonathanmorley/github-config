# GitHub Config

OpenTofu-managed configuration for all `jonathanmorley/*` repositories.

## What It Manages

- Repository settings (auto-merge, features, merge strategies)
- Dependabot alerts and automated security fixes on every managed repo
- Drift detection via daily scheduled runs
- Automated enforcement via PR merges

## Usage

### Local Development

```bash
tofu init
tofu plan    # Preview changes
tofu apply   # Apply changes
```

### How It Works

1. **Discovery:** Automatically finds all repos in the `jonathanmorley` namespace
2. **Defaults:** Applies uniform settings from `variables.tf`
3. **Exclusions:** Skip repos via `excluded_repos` variable
4. **Overrides:** Per-repo exceptions via `repo_overrides` variable (future)
5. **Adoption:** Every managed object is imported (not created out-of-band) — see below

### Imports for every resource

Every managed GitHub object pre-exists on GitHub, so each `resource` block must
have a matching `import` block that adopts it into state. This avoids out-of-band
creation (and the drift and destructive applies that follow). This rule is
enforced automatically by `scripts/check-imports.sh` in CI on every plan. If a
future resource is intentionally create-only, annotate its `resource` line with
`# no-import` to exempt it.

## Security Settings

Dependabot alerts and automated security fixes are enforced on every managed repository via
`github_repository_vulnerability_alerts` and `github_repository_dependabot_security_updates` in
`repos.tf`. Both features are free on personal accounts, including private repositories.
Settings that lack provider resources today (private vulnerability reporting, CodeQL default setup)
are tracked for follow-up via a patched provider build.

"Require actions to be pinned to a full-length commit SHA" is enforced on every managed repository via
`github_actions_repository_permissions` with `sha_pinning_required = true`. This blocks builds that
reference actions or reusable workflows by mutable tag, ensuring only immutable commit SHAs are used.

### Follow-ups awaiting a stable GitHub API

The following GitHub security features are not yet enforceable via this config:

- **"Require lockfiles"** (native Actions setting) — no public REST/GraphQL endpoint exists.
- **Actions policies / workflow execution protections** (actor and event rules that restrict who can
  trigger workflows and which events may run them) — in public preview, built on the rulesets
  framework, but the actor/event rule types are not yet exposed in the public REST API or the
  provider's `github_repository_ruleset` resource.

These are tracked for follow-up once GitHub exposes a stable API and the provider gains support.

## Authentication

This repo uses [Octo STS](https://github.com/chainguard-dev/octo-sts) for short-lived GitHub credentials. The trust policy is at `jonathanmorley/.github/.github/chainguard/terraform.sts.yaml`.

State is ephemeral — each workflow run imports all repos fresh from GitHub. No state persistence needed.

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
