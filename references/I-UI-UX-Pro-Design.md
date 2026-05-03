# Section I - UI/UX Pro Design Skill

## Goal

Install and use the `nextlevelbuilder/ui-ux-pro-max-skill` workflow in this workspace, with a reliable fallback when `github copilot install` is unavailable.

## Quick Outcome (Current Machine)

- Repository clone: success
- Command `github copilot install nextlevelbuilder/ui-ux-pro-max-skill`: unavailable (no `github` executable)
- `gh` installed: yes
- `gh copilot` extension installed: yes, but it does not provide an `install` command

## Reusable Installation Workflow

### 1. Clone the skill repository

```powershell
Set-Location "D:\laragon\www\aspnet-fullstack-skill"
git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill.git
```

### 2. Try the requested install command

```powershell
github copilot install nextlevelbuilder/ui-ux-pro-max-skill
```

Decision:
- If it succeeds, continue to verification.
- If it fails with command not found, continue with fallback install.

### 3. Fallback install (manual, deterministic)

Preferred workspace path (team-shared):

```powershell
Set-Location "D:\laragon\www\aspnet-fullstack-skill"
New-Item -ItemType Directory -Force -Path ".github\skills\ui-ux-pro-max" | Out-Null
Copy-Item -Recurse -Force ".\ui-ux-pro-max-skill\.claude\skills\ui-ux-pro-max\*" ".github\skills\ui-ux-pro-max\"
```

Alternative workspace paths supported by tooling:
- `.agents/skills/ui-ux-pro-max/`
- `.claude/skills/ui-ux-pro-max/`

Personal (cross-workspace) path options:
- `%USERPROFILE%\.copilot\skills\ui-ux-pro-max\`
- `%USERPROFILE%\.agents\skills\ui-ux-pro-max\`
- `%USERPROFILE%\.claude\skills\ui-ux-pro-max\`

### 4. Verify installation

Checklist:
- Skill folder exists at one supported location.
- `SKILL.md` exists.
- Frontmatter `name` matches folder name: `ui-ux-pro-max`.
- `description` contains strong trigger keywords so the skill is discoverable.
- Referenced assets/scripts use relative `./` paths.

Verification commands:

```powershell
Test-Path ".github\skills\ui-ux-pro-max\SKILL.md"
Get-Content ".github\skills\ui-ux-pro-max\SKILL.md" -TotalCount 30
```

### 5. Run a smoke prompt

Use one of these prompts:
- "Design a responsive SaaS dashboard page with strong hierarchy and accessibility checks."
- "Refactor this login form UI using a consistent style system and better error feedback."
- "Review this component for UX, contrast, interaction states, and mobile touch targets."

## Branching Logic Summary

- Branch A: `github copilot install` works -> use official install path.
- Branch B: command missing / unsupported -> clone + copy skill folder manually.
- Branch C: installed but not discovered -> improve `description` keywords and re-check folder path.

## Quality Criteria / Completion Checks

- Installation is reproducible with copy-paste commands.
- Skill path follows supported location rules.
- Skill discovery works through keyword-rich `description`.
- At least one smoke prompt triggers useful UI/UX guidance.

## Draft Skill Scaffold (Reusable)

Create in `.github/skills/ui-ux-pro-max/SKILL.md` if you want a workspace-owned variant:

```markdown
---
name: ui-ux-pro-max
description: "UI/UX design intelligence for web and mobile. Use when planning, designing, reviewing, or improving pages, components, accessibility, interaction states, typography, color systems, responsive layouts, and visual consistency."
argument-hint: "What are you designing or reviewing?"
user-invocable: true
disable-model-invocation: false
---

# UI/UX Pro Max

## When to Use
- New page design (landing page, dashboard, admin, e-commerce)
- Component refactor (forms, tables, cards, modals, nav)
- UX/accessibility review before release

## Procedure
1. Identify product context and target audience.
2. Select style direction and constraints.
3. Define color and typography system.
4. Apply layout and responsive rules.
5. Validate accessibility and interaction quality.
6. Return implementation guidance and acceptance checklist.
```

## Ambiguous Points To Confirm

1. Installation scope: workspace-only (`.github/skills`) or personal profile (`~/.copilot/skills`)?
2. Should this repository keep only the upstream skill as-is, or maintain a customized local fork of `SKILL.md`?
3. Should we add an automation script (for example `scripts/install-ui-ux-skill.ps1`) so future setup is one command?
