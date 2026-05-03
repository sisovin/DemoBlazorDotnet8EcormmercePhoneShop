# Section G — GitHub Workflow Skills

## Table of Contents
1. [Branching Strategy — Git Flow](#1-branching-strategy--git-flow)
2. [Commit Message Convention (Conventional Commits)](#2-commit-message-convention)
3. [Pull Requests & Code Reviews](#3-pull-requests--code-reviews)
4. [Issue Tracking](#4-issue-tracking)
5. [Release Management](#5-release-management)
6. [Repository Configuration Standards](#6-repository-configuration-standards)
7. [Branch Protection Rules](#7-branch-protection-rules)
8. [.gitignore for ASP.NET](#8-gitignore-for-aspnet)

---

## 1. Branching Strategy — Git Flow

### Branch Topology

```
main            ─── Production. Tagged at each release. Never commit directly.
  └── develop   ─── Integration branch. All features merge here first via PR.
        │
        ├── feature/APP-101-product-search        ← branched from develop
        ├── feature/APP-102-user-dashboard
        ├── bugfix/APP-200-null-ref-in-cart
        ├── refactor/APP-201-extract-pricing-svc
        └── release/v1.3.0     ← cut from develop, merged to main + develop on release

hotfix/APP-999-critical-auth-bypass   ← branched from main; merged to BOTH main + develop
chore/upgrade-ef-core-8               ← tooling, deps, config; branched from develop
```

### Branch Naming Convention

| Prefix | Pattern | Example |
|---|---|---|
| Feature | `feature/{ticket}-{slug}` | `feature/APP-101-product-catalog` |
| Bug fix | `bugfix/{ticket}-{slug}` | `bugfix/APP-202-cart-total-rounding` |
| Hotfix | `hotfix/{ticket}-{slug}` | `hotfix/APP-303-login-500-on-null-user` |
| Release | `release/v{M}.{m}.{p}` | `release/v2.1.0` |
| Refactor | `refactor/{slug}` | `refactor/extract-order-service` |
| Chore | `chore/{slug}` | `chore/upgrade-pomelo-mysql` |
| Docs | `docs/{slug}` | `docs/update-api-readme` |

### Daily Developer Workflow

```bash
# ── Start a new feature ─────────────────────────────────────────────
git checkout develop
git pull --rebase origin develop
git checkout -b feature/APP-101-product-catalog

# ── Work in small, focused commits ──────────────────────────────────
git add src/MyApp.Application/Services/ProductService.cs
git commit -m "feat(product): add paginated catalog query with category filter"

git add src/MyApp.Web/Controllers/ProductController.cs
git commit -m "feat(product): add catalog controller with search action"

git add tests/MyApp.Application.Tests/ProductServiceTests.cs
git commit -m "test(product): add unit tests for catalog pagination"

# ── Keep up-to-date with develop (prefer rebase over merge) ─────────
git fetch origin
git rebase origin/develop
# Resolve conflicts if any, then:
git rebase --continue

# ── Push and open Pull Request ───────────────────────────────────────
git push -u origin feature/APP-101-product-catalog
# → Open PR: feature/APP-101-product-catalog → develop on GitHub

# ── After PR is approved and merged ─────────────────────────────────
git checkout develop
git pull --rebase origin develop
git branch -d feature/APP-101-product-catalog
```

### Hotfix Workflow

```bash
# Critical production bug — branch from main, not develop
git checkout main
git pull --rebase origin main
git checkout -b hotfix/APP-999-payment-null-ref

# Fix, test, commit
git commit -m "fix(payment): handle null gateway response on timeout"

# Merge to BOTH main and develop
git checkout main
git merge --no-ff hotfix/APP-999-payment-null-ref
git tag v1.2.1

git checkout develop
git merge --no-ff hotfix/APP-999-payment-null-ref

git push origin main develop --tags
git branch -d hotfix/APP-999-payment-null-ref
```

### Release Workflow

```bash
# Cut release branch from develop
git checkout develop && git pull --rebase origin develop
git checkout -b release/v1.3.0

# Bump version, update CHANGELOG, final testing
# Only bug fixes allowed on release branch — no new features

# Merge to main and tag
git checkout main
git merge --no-ff release/v1.3.0
git tag -a v1.3.0 -m "Release v1.3.0 — product catalog and performance improvements"

# Back-merge to develop
git checkout develop
git merge --no-ff release/v1.3.0

git push origin main develop --tags
git branch -d release/v1.3.0
```

---

## 2. Commit Message Convention

Format: **Conventional Commits v1.0** — https://www.conventionalcommits.org

```
<type>(<scope>): <short description>
                  │
                  └── Imperative mood, lowercase, no period, max 72 chars
                      "add" not "added" / "adds"

[optional body]
  - Explain WHAT and WHY, not HOW
  - Wrap at 100 chars

[optional footer]
  - BREAKING CHANGE: <description>
  - Refs: #issue-number
  - Co-authored-by: Name <email>
```

### Types Reference

| Type | When to Use | Triggers SemVer |
|---|---|---|
| `feat` | New feature (visible to consumer) | Minor bump |
| `fix` | Bug fix | Patch bump |
| `refactor` | Code restructure — no behaviour change | — |
| `perf` | Performance improvement | Patch bump |
| `test` | Add or update tests | — |
| `docs` | Documentation only | — |
| `style` | Formatting, whitespace (no logic change) | — |
| `build` | Build system, NuGet, npm changes | — |
| `ci` | CI/CD pipeline changes | — |
| `chore` | Tooling, release automation | — |
| `revert` | Reverts a previous commit | — |

### Examples

```bash
# Good — scoped, imperative, precise
git commit -m "feat(auth): add JWT refresh token rotation endpoint"
git commit -m "fix(product): handle null category in catalog listing query"
git commit -m "refactor(repo): extract generic RepositoryBase<T> class"
git commit -m "test(order): add unit tests for order total recalculation"
git commit -m "perf(db): add composite index on (category_id, price)"
git commit -m "chore: upgrade Pomelo.EntityFrameworkCore.MySql to 8.0.2"
git commit -m "docs(api): add Swagger XML comments to ProductsController"

# Breaking change
git commit -m "feat(api)!: remove deprecated v1 product endpoints

BREAKING CHANGE: /api/v1/products has been removed.
Use /api/v2/products instead. See migration guide in docs/migration-v2.md.

Refs: #234"

# Bad — vague, past tense, no type
git commit -m "fixed bug"
git commit -m "updated stuff"
git commit -m "WIP"
```

---

## 3. Pull Requests & Code Reviews

### PR Template (.github/pull_request_template.md)

```markdown
## Description
<!-- What does this PR do and why? Link to the design doc or issue. -->

## Related Issues
Closes #<!-- issue number -->
Refs #<!-- related issue -->

## Type of Change
- [ ] `feat` — New feature (non-breaking)
- [ ] `fix` — Bug fix (non-breaking)
- [ ] `feat!` — Breaking change
- [ ] `refactor` — Code cleanup (no functional change)
- [ ] `docs` — Documentation update
- [ ] `ci` — Pipeline / tooling change

## Testing
- [ ] Unit tests added / updated and passing
- [ ] Integration tests passing
- [ ] Manual testing performed (describe steps below)
- [ ] No new compiler warnings

## Checklist
- [ ] Code follows project conventions (naming, formatting, SOLID)
- [ ] Self-review completed — I have read my own diff
- [ ] No hardcoded secrets, passwords, or connection strings
- [ ] `appsettings.json` contains no sensitive values
- [ ] EF Core migration included (if schema changed)
- [ ] Swagger/OpenAPI comments updated (if API changed)
- [ ] `CHANGELOG.md` updated (for `feat` and `fix` PRs)

## Screenshots (if UI changed)
<!-- Before / After screenshots -->

## Additional Notes
<!-- Anything the reviewer needs to know: gotchas, trade-offs, follow-up tasks -->
```

### Code Review Standards

**Reviewer Responsibilities:**
- Approve only code you understand and would be comfortable owning
- Use GitHub suggestion blocks (`Ctrl+G`) for small fixes — don't just comment
- Distinguish between blocking issues and non-blocking nits using prefixes:
  - `[blocking]` — Must be fixed before merge
  - `[nit]` — Style preference, author's discretion
  - `[question]` — Clarification needed, not necessarily a change

**Review Checklist:**
```
Architecture
  □ No business logic in controllers or views
  □ Interfaces used for all service/repository dependencies
  □ Layer dependencies flow in the correct direction
  □ No circular dependencies

Security
  □ No raw SQL with user input (EF Core parameterized or @param)
  □ [ValidateAntiForgeryToken] on all POST actions (MVC)
  □ Sensitive data not logged or included in API responses
  □ File uploads validated by magic bytes, not extension alone

Data Access
  □ AsNoTracking() on read-only EF Core queries
  □ CancellationToken threaded through async call chain
  □ No N+1 queries (Include / projection or split queries used)
  □ Migrations reviewed for correctness and reversibility

Code Quality
  □ No async void (except event handlers)
  □ No .Result / .Wait() on Tasks (deadlock risk)
  □ No magic strings / numbers — constants or enums used
  □ No unused usings, variables, or dead code

Testing
  □ New features have unit tests
  □ Bug fixes have regression tests
  □ Test names follow MethodName_Scenario_ExpectedResult pattern
```

### Merge Strategy

```
feature/* → develop:   Squash merge    (keep develop history clean)
bugfix/*  → develop:   Squash merge
release/* → main:      Merge commit    (preserve release history)
hotfix/*  → main:      Merge commit
release/* → develop:   Merge commit
hotfix/*  → develop:   Merge commit
```

---

## 4. Issue Tracking

### Issue Templates

**.github/ISSUE_TEMPLATE/bug_report.md**

```markdown
---
name: Bug Report
about: Report a reproducible defect
labels: ["bug", "triage"]
assignees: ""
---

## Environment
- **ASP.NET Version:** 8.0 / MVC 5
- **OS / Hosting:** Ubuntu 22.04 / IIS / Docker
- **Browser (if UI):** Chrome 123
- **Database:** MySQL 8.0

## Description
<!-- Clear, concise description of the bug -->

## Steps to Reproduce
1. Navigate to `/product/create`
2. Submit form with Price = 0
3. Observe 500 Internal Server Error

## Expected Behaviour
<!-- What should happen -->

## Actual Behaviour
<!-- What actually happens — include error messages, stack traces -->

## Minimal Reproduction
<!-- Repo link, code snippet, or curl command -->

## Logs / Screenshots
<!-- Paste relevant log output -->
```

**.github/ISSUE_TEMPLATE/feature_request.md**

```markdown
---
name: Feature Request
about: Propose a new feature or enhancement
labels: ["enhancement", "triage"]
---

## Problem Statement
<!-- What user need or pain point does this address? -->
<!-- "As a [role], I want [capability] so that [benefit]." -->

## Proposed Solution
<!-- Describe your proposed approach -->

## Acceptance Criteria
- [ ] Given [context], when [action], then [outcome]
- [ ] API endpoint returns correct status code
- [ ] Unit tests cover the happy path and edge cases

## Alternatives Considered
<!-- Why was this approach chosen over others? -->

## Additional Context
<!-- Mockups, links to related issues, documentation -->
```

### Labels System

```
Type:       bug · feature · refactor · docs · security · performance
Priority:   P0-critical · P1-high · P2-medium · P3-low
Status:     triage · in-progress · blocked · ready-for-review · wont-fix
Layer:      backend · frontend · database · infrastructure · ci-cd
```

---

## 5. Release Management

### CHANGELOG.md Format (Keep a Changelog)

```markdown
# Changelog

All notable changes to MyApp are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] — 2025-05-15

### Added
- Product catalog search with category and price range filters (#101)
- JWT refresh token rotation endpoint (`POST /api/auth/refresh`) (#98)
- Rate limiting on authentication endpoints (5 requests/minute per IP) (#105)

### Changed
- Upgraded Pomelo.EntityFrameworkCore.MySql from 7.0.0 to 8.0.2
- API pagination default page size changed from 10 to 20

### Fixed
- Order total not recalculating after item quantity update (#200)
- Null reference on product create when category is deleted (#202)

### Security
- Added `X-Content-Type-Options: nosniff` to all responses
- Passwords no longer included in user profile API response

## [1.2.1] — 2025-04-01

### Fixed
- Critical: null gateway response causing 500 on payment timeout (#303)

## [1.2.0] — 2025-03-15
...
```

### Semantic Versioning Rules

| Change | Version Bump | Example |
|---|---|---|
| Breaking API change | MAJOR `X.0.0` | Remove endpoint, rename field |
| New feature (backward-compatible) | MINOR `1.X.0` | Add endpoint, add optional field |
| Bug fix, security patch | PATCH `1.2.X` | Fix crash, patch CVE |
| Pre-release | Pre-release suffix | `1.3.0-beta.1` |

### GitHub Release Automation

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ["v*"]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions: { contents: write }

    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }

      - name: Extract CHANGELOG section for this version
        id: changelog
        run: |
          VERSION="${GITHUB_REF_NAME#v}"
          NOTES=$(sed -n "/^## \[$VERSION\]/,/^## \[/{ /^## \[/d; p }" CHANGELOG.md)
          echo "notes<<EOF" >> $GITHUB_OUTPUT
          echo "$NOTES"    >> $GITHUB_OUTPUT
          echo "EOF"       >> $GITHUB_OUTPUT

      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: "8.0.x" }

      - name: Publish artifacts
        run: |
          dotnet publish src/MyApp.Web -c Release -r linux-x64 \
            --self-contained -o publish/linux-x64
          zip -r myapp-linux-x64.zip publish/linux-x64

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: "Release ${{ github.ref_name }}"
          body: ${{ steps.changelog.outputs.notes }}
          draft: false
          prerelease: ${{ contains(github.ref_name, '-') }}
          files: |
            myapp-linux-x64.zip
```

---

## 6. Repository Configuration Standards

### Repository Secrets (Settings → Secrets and Variables → Actions)

```
PROD_HOST          ← Production server IP or hostname
PROD_USER          ← SSH username
PROD_SSH_KEY       ← Private key (PEM format, no passphrase for CI)
DB_PASSWORD        ← Production database password
JWT_KEY            ← JWT signing key (≥ 32 characters)
DOCKER_USERNAME    ← Docker Hub / GHCR username
CODECOV_TOKEN      ← Codecov upload token
AZURE_CREDENTIALS  ← Azure service principal JSON (if using Azure)
```

### Dependabot Configuration (.github/dependabot.yml)

```yaml
version: 2
updates:
  - package-ecosystem: nuget
    directory: /
    schedule: { interval: weekly, day: monday }
    open-pull-requests-limit: 5
    labels: ["dependencies", "dotnet"]
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major"]   # Major bumps need manual review

  - package-ecosystem: npm
    directory: /src/MyApp.Web
    schedule: { interval: weekly }
    labels: ["dependencies", "frontend"]

  - package-ecosystem: docker
    directory: /
    schedule: { interval: weekly }
    labels: ["dependencies", "docker"]

  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
    labels: ["dependencies", "ci-cd"]
```

---

## 7. Branch Protection Rules

Configure under **Settings → Branches → Add Rule**:

### `main` branch

```
✅ Require a pull request before merging
   └─ Required approvals: 2
   └─ Dismiss stale PR approvals on new commits
   └─ Require review from Code Owners
✅ Require status checks to pass before merging
   └─ Required checks: CI / test, CI / docker, security-scan
   └─ Require branches to be up to date
✅ Require conversation resolution before merging
✅ Require signed commits
✅ Require linear history (enforces squash/rebase — no merge commits)
✅ Include administrators
✅ Restrict who can push: only release managers
```

### `develop` branch

```
✅ Require a pull request before merging
   └─ Required approvals: 1
✅ Require status checks: CI / test
✅ Require conversation resolution
✅ Require linear history
```

### CODEOWNERS (.github/CODEOWNERS)

```
# Global owners
*                               @team-leads

# Architecture & infrastructure
src/MyApp.Domain/               @senior-devs
src/MyApp.Infrastructure/       @senior-devs
src/MyApp.Infrastructure/Data/Migrations/  @senior-devs @dba-team

# Security-sensitive files
src/MyApp.Web/Controllers/AuthController.cs  @security-team
references/B-backend.md                     @security-team

# CI/CD
.github/                        @devops-team
**/Dockerfile                   @devops-team
**/docker-compose*.yml          @devops-team
```

---

## 8. .gitignore for ASP.NET

```gitignore
## .gitignore — ASP.NET Core + MVC 5 + Node.js

# ── Build output ────────────────────────────────────────────────────
[Bb]in/
[Oo]bj/
[Ll]og/
[Ll]ogs/
publish/
out/

# ── Visual Studio ───────────────────────────────────────────────────
.vs/
*.suo
*.user
*.userosscache
*.sln.docstates
*.userprefs
*.pidb

# ── .NET / ASP.NET ──────────────────────────────────────────────────
project.lock.json
project.fragment.lock.json
artifacts/

# ── User secrets (never commit) ─────────────────────────────────────
**/Properties/launchSettings.json
**/Properties/PublishProfiles/

# appsettings — commit the template, never env-specific files with secrets
appsettings.Production.json
appsettings.Staging.json
!appsettings.json
!appsettings.Development.json

# ── Entity Framework ────────────────────────────────────────────────
*.mdf
*.ldf
*.ndf

# ── NuGet ───────────────────────────────────────────────────────────
packages/
*.nupkg
*.snupkg
.nuget/

# ── Node / npm / Tailwind ───────────────────────────────────────────
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Generated CSS (built from Tailwind input.css — do NOT commit)
wwwroot/css/site.css
wwwroot/css/site.min.css
wwwroot/js/site.min.js

# ── Docker ──────────────────────────────────────────────────────────
.env
.env.*
!.env.example     # Commit the example template only

# ── Test results ────────────────────────────────────────────────────
TestResults/
*.trx
*.coveragexml
coverage/
*.coverage
lcov.info

# ── OS ──────────────────────────────────────────────────────────────
.DS_Store
Thumbs.db
desktop.ini
ehthumbs.db

# ── JetBrains Rider ─────────────────────────────────────────────────
.idea/
*.sln.iml

# ── ReSharper ───────────────────────────────────────────────────────
_ReSharper*/
*.[Rr]e[Ss]harper
*.DotSettings.user

# ── Compiled static assets (committed: source; excluded: output) ─────
wwwroot/lib/      # Managed by LibMan or npm — exclude from git

# ── Security ────────────────────────────────────────────────────────
*.pfx
*.p12
*.key
*.pem
!*.example.pem   # Example/template cert files are OK to commit
secrets.json
```