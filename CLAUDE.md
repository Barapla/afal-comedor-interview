# CLAUDE.md — Afal Comedor Interview

> Project context and configuration for AI-assisted development.
> Read `.claude/ENGINEERING_STANDARDS.md` before writing any code.

---

## What is this project

Comedor AFAL — API/app interna en Rails 8 para el comedor de empleados: menú diario, pedidos, control de stock por platillo y descuento de nómina según subsidio diario. Repo de prueba técnica (fork), datos sintéticos.

---

## Stack

Ruby on Rails, PostgreSQL

---

## Technical Decisions

No specific decisions detected.

---

## Conventions

Standard project conventions

---

## Language

All ticket content and code comments: **Spanish (es)**

---










## PM Agent Integration

This project is managed by the Brainmachine PM Agent.

| Variable | Value |
|---|---|
| `PM_AGENT_URL` | `http://localhost:3000` |
| `PM_AGENT_API_KEY` | Set in `.env` |
| `PROJECT_NAME` | `Afal Comedor Interview` |

### Resolve ticket ID

```bash
curl -s "http://localhost:3000/api/v1/tickets?identifier=FEAT-001&project=Afal Comedor Interview" \
  -H "X-Api-Key: $PM_AGENT_API_KEY"
```

### Mark ticket complete

```bash
curl -X POST http://localhost:3000/api/v1/tickets/{id}/complete \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PM_AGENT_API_KEY" \
  -d '{
    "branch": "<current-branch>",
    "pr_url": "<pr-url>",
    "summary": "<summary>",
    "technical_decisions": "<decisions>",
    "how_to_test": "<steps>"
  }'
```

---

## Engineering Standards

Standards live in the `.claude/` folder:

| File | Content |
|---|---|
| `ENGINEERING_STANDARDS.md` | Git, commits, PR, API communication, error format |
        | `RAILS_STANDARDS.md` | Result pattern, service objects, serializers, DB, RuboCop, RSpec |

---

## PM Agent Managed Files — DO NOT MODIFY OR REGENERATE

The following files are generated and managed by the Brainmachine PM Agent.
They must NEVER be regenerated, overwritten, or modified manually.
If a task asks you to set up CI or configure GitHub Actions, verify these files exist — do NOT recreate them.

| File | Managed by |
|---|---|
| `.github/scripts/claude_review.rb` | PM Agent — StandardsManager |
| `.github/workflows/claude-review.yml` | PM Agent — StandardsManager |

CRITICAL: `.github/scripts/claude_review.rb` must NEVER be regenerated.
It uses `CLAUDE_API_KEY`, parses the PR number from `GITHUB_REF`, and references `GITHUB_REPOSITORY`.
Any version that uses `ANTHROPIC_API_KEY`, `PR_NUMBER` as a literal env var, or `REPO` is incorrect.
