# GitHub Config

OpenTofu-managed configuration for all `jonathanmorley/*` repositories.

## What It Manages

- Repository settings (auto-merge, features, merge strategies)
- Dependabot alerts and automated security fixes on every managed repo
- Default-branch protection on every applicable managed repo (see below)
- Drift detection via daily scheduled runs
- Automated enforcement via PR merges

Archived repos are excluded from management entirely.

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
3. **Archived:** Repos that are archived are excluded from all management
4. **Exclusions:** Skip repos via `excluded_repos` variable
5. **Overrides:** Per-repo exceptions via `repo_overrides` variable (future)
6. **Adoption:** Every managed object is imported (not created out-of-band) — see below

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
Settings that lack provider resources upstream are provided via the patched provider fork
(`registry.terraform.io/jonathanmorley/github`), such as `github_repository_immutable_releases`.

"Require actions to be pinned to a full-length commit SHA" is enforced on every managed repository via
`github_actions_repository_permissions` with `sha_pinning_required = true` and `allowed_actions = "all"`.
This blocks builds that reference actions or reusable workflows by mutable tag, ensuring only immutable
commit SHAs are used. `allowed_actions` is set to `"all"` explicitly because SHA pinning only applies
when all actions are allowed (it is not applicable to `local_only` or `selected`).

**"Enable release immutability"** is enforced on every managed repository via
`github_repository_immutable_releases` in `repos.tf`. Once enabled, the content of existing and future
releases cannot be modified or deleted, protecting release provenance and integrity. This setting is
backed by the stable public REST API (`/repos/{owner}/{repo}/immutable-releases`) and is provided by the
patched provider fork.

### Default-branch protection

Every applicable managed repository gets a branch ruleset on its default branch via
`github_repository_ruleset` in `repos.tf`:

- Require a pull request before merging (0 required approvals)
- Require conversation resolution
- Require linear history (blocks merge commits)
- Require signed commits
- Block force pushes and branch deletion
- Enforced for everyone (no bypass actors)

Forked repos are excluded (they need direct-push workflows to track upstreams). Repos already protected
by their own rulesets are excluded by default via the `ruleset_excluded_repos` variable so the two
mechanisms don't collide; add any future repos that manage their own protection to that list. Private
repos are also excluded: repository rulesets are a paid feature on GitHub's free plan, and GitHub
refuses them for private repos (403 "Upgrade to GitHub Pro or make this repository public to enable
this feature.").

**Why a ruleset instead of classic branch protection?** Rulesets are the modern, recommended
mechanism and are what GitHub enforces in the UI. The tradeoff: classic branch protection can express
"require branches to be up to date" without pinning specific checks (`strict` + empty `contexts`),
whereas rulesets reject `required_status_checks` with an empty check list. Since CI varies per repo,
the check-agnostic "up to date" gate cannot be expressed in a rule set — the strictness of that single
check is the price of the simpler, uniform mechanism.

**Bootstrap phase:** these rules are brand-new, so the resource is currently annotated `# no-import`
and has no `import` block — the first Terraform apply creates them. A follow-up change adds the
`import` blocks (via the `github_repository_rulesets` data source) once the rules exist, so
ephemeral-state runs adopt instead of recreate. The rules are only ever created or modified through
this Terraform deployment.

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
