# ENGINEERING_STANDARDS.md — Universal Engineering Rules
> These rules apply to ALL projects, regardless of stack.
> Stack-specific rules live in RAILS_STANDARDS.md, REACT_STANDARDS.md, etc.

> ⚠️ STOP — This document defines the mandatory development workflow. It is not optional, it is not a guide.
> Every step must be executed in order. Skipping a step invalidates the work.

---

## Ticket Workflow

### Naming Conventions
```
feature/FEAT-XXX-short-description
bugfix/BUG-XXX-short-description
hotfix/CRITICAL-short-description
```

### Ticket States
- `backlog` → `to do` → `in progress` → `peer review` → `done`
- A ticket returned to `back to dev` goes back to `in progress` when retaken

### Rules
- 1 ticket = 1 branch = 1 commit (squash WIP commits before final push)
- `ticket_number` is auto-incremental by `ticket_type`, not global
- Always record the TicketLog regardless of the result (success or failure)

---

## Git Workflow

### Commits
Use Conventional Commits:
```
feat(scope): description in imperative
fix(scope): description of bug corrected
tech(scope): technical debt or refactor
```

Prohibited:
- Direct commit to `main` or `development`
- Push with linter or security check errors
- Commits with `binding.pry`, debug `puts`, or `console.log`

### Merge Strategy
- PRs merge to `development`, never directly to `main`
- Squash merge to keep clean history when there are WIP commits

---

## Pull Request Standards

### Source of Truth
The content of each PR MUST follow `.github/PULL_REQUEST_TEMPLATE.md` of the project.
Before creating the PR, read the template from the filesystem — never invent generic descriptions.

### Mandatory Sections
Every PR must include:
- **Ticket**: Direct link to the ticket and reference to the ID (e.g. FEAT-015)
- **What does this PR do?**: Executive summary of the change
- **Change type**: feat / fix / hotfix / tech / spike
- **How to test?**: Exact steps to verify the change
- **Technical decisions (ADRs)**: Justification of non-obvious choices

### Prohibitions
- Do not leave empty sections or with placeholder text from the template
- Do not add auto-generated footers not in the template
- Do not create PRs without passing specs

### Creation Process
```bash
# Read GITHUB_TOKEN from .env
GITHUB_TOKEN=$(grep GITHUB_TOKEN .env | cut -d '=' -f2)

# Write body to a temp file to avoid escaping issues
cat > /tmp/pr_body.json << 'EOF'
{
  "title": "FEAT-XXX — Exact ticket title",
  "body": "...content following the template...",
  "head": "feature/FEAT-XXX-description",
  "base": "development"
}
EOF

curl -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/ORG/REPO/pulls \
  --data @/tmp/pr_body.json
```

---

## API Communication

### JSON Payloads
- NEVER use backticks (`), asterisks (`*`) or Markdown escapes in JSON values
- Use plain text. For emphasis: UPPERCASE or single quotes
- If the API responds 400 (Bad Request), assume illegal characters in the JSON and clean them before retrying

### Identifier vs Database ID
- The ticket number (e.g. `FEAT-014`) is NOT the database ID
- The database ID (Primary Key) is the ONLY valid one for API URLs
- Never assume ID increments — always resolve via search endpoint
- Never hardcode IDs in commands

### Error Handling in API Calls
If the API responds with 400 or 404:
1. Read the error log if available
2. Identify if the JSON is malformed or the ID is incorrect
3. Fix the payload and retry ONE time only
4. If it fails again, stop and ask for clarification

### Data Integrity
Before executing a POST or PATCH, verify that the data corresponds to the current project and ticket.
Do not overwrite records from other tickets based on numbering assumptions.

---

## Error Formatting

### HTTP Error Structure
```json
{
  "error": {
    "code": "validation_error",
    "message": "Human-readable description of the error",
    "details": {}
  }
}
```

### Logging Standards
- Log errors with enough context (what failed, with what input)
- External service errors (third-party APIs) → log without re-raise to avoid exhausting retries
- Business logic errors → raise to propagate to the caller
- Never suppress errors silently without at least one log entry

---

## Workflow Requirements

### API Changes

If your ticket creates, modifies, or removes endpoints, you MUST update `API_ENDPOINTS.md` before the final commit.

- Add new endpoints to the table with method, path, auth, request body, response body, and notes
- Update existing rows when the contract changes (auth method, request/response format, path)
- Remove rows for deleted endpoints

**This rule is mandatory. A PR that changes API behavior without updating `API_ENDPOINTS.md` must not be merged.**

---

## New Feature Workflow

> The values `{API_KEY}`, `{PROJECT_NAME}`, `{ORG/REPO}` are project-specific.
> Find them in the **Project-specific configuration** section of the project's CLAUDE.md.

### ⚠️ STOP — Verify your branch BEFORE writing any line of code

```bash
git branch --show-current
```

| Current branch | Immediate action |
|---|---|
| `development` or `main` | `git checkout development && git pull && git checkout -b feature/FEAT-XXX-desc` |
| Another ticket's branch | `git stash && git checkout development && git pull && git checkout -b feature/FEAT-XXX-desc` |
| Correct branch for this ticket | Proceed to step 1 |

**There is no step zero. If you are not on the correct branch, stop here and fix it before writing any code.**

---

1. Read the full ticket and extract the ID and description (e.g. `FEAT-004`)
2. Verify and fix the current branch — see table above. Do not continue to step 3 until on the correct branch.
3. Implement: migration if applicable → model → service → serializer → controller → specs
4. Linter 0 offenses → security checks 0 new warnings → specs passing
5. `git add <specific files> && git commit -m "feat(scope): description"`
6. `git push origin feature/FEAT-XXX-description`
7. Update `MEMORY.md` — add new models, endpoints, migrations and specs. Move Pending items to their section if applicable.
8. Read `.github/PULL_REQUEST_TEMPLATE.md` of the project. Create the PR via GitHub API:
   ```bash
   GITHUB_TOKEN=$(grep GITHUB_TOKEN .env | cut -d '=' -f2)

   cat > /tmp/pr_body.json << 'EOF'
   {
     "title": "<exact ticket title>",
     "body": "<content following PULL_REQUEST_TEMPLATE.md>",
     "head": "<git branch --show-current>",
     "base": "development"
   }
   EOF

   curl -X POST \
     -H "Authorization: Bearer $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/{ORG/REPO}/pulls \
     --data @/tmp/pr_body.json
   ```
   Save the `html_url` from the PR response.
9. Resolve the real TicketLog ID — **NEVER assume the ticket number is the DB ID**:
   ```bash
   curl -s "http://localhost:3000/api/v1/tickets?identifier=FEAT-XXX&project={PROJECT_NAME}" \
     -H "X-Api-Key: {API_KEY}"
   ```
   Extract the `id` field from the JSON. Use it exactly as it comes.
10. Call the `/complete` endpoint with the ID obtained in the previous step:
    ```bash
    curl -X POST http://localhost:3000/api/v1/tickets/{id}/complete \
      -H "Content-Type: application/json" \
      -H "X-Api-Key: {API_KEY}" \
      -d "{
        \"branch\": \"<git branch --show-current>\",
        \"pr_url\": \"<html_url from step 8>\",
        \"summary\": \"<technical summary — plain text, no markdown>\",
        \"technical_decisions\": \"<decisions made — plain text>\",
        \"how_to_test\": \"<steps to test the feature>\"
      }"
    ```
11. Verify that `/complete` returned success with the `pr_url`.

### ⚠️ Definition of Done — The ticket is NOT finished until:
- [ ] You are on the correct ticket branch
- [ ] `git push` executed successfully
- [ ] PR was created and you have the `html_url`
- [ ] `/complete` returned success

**If any of these points were not met, the work is incomplete. There is no valid intermediate state.**

### Never
- Direct commit to `main` or `development`
- Push with linter or security check errors
- 1 ticket = 1 branch = 1 commit

---

## Data Scripts

### Overview

Rails migrations are for **schema changes** (add column, create table, add index).
Data scripts are for **data changes** (backfill records, correct values, migrate existing data).

These must be kept separate to maintain clear intent, enable independent review, and allow safe rollback without touching the schema.

### Mandatory Rules

- **Directory**: all scripts live in `lib/data_scripts/`
- **Naming**: `DATA-XXX_YYYY-MM-DD_short-description.rb` (e.g. `DATA-001_2026-03-10_seed-brain-machine-org.rb`)
- **No auto-execution**: scripts are NEVER run automatically; execution is always manual and supervised
- **One script per ticket**: each DATA ticket produces exactly one script file
- **Committed in PR**: the script is reviewed in code review before being executed in any environment

### Required Structure

Every data script must define three methods:

| Method | Purpose |
|---|---|
| `up` | Executes the data change |
| `verify` | Validates the expected result after running `up` |
| `rollback` | Reverses the change if something went wrong |

### Script Template

```ruby
# frozen_string_literal: true

# DATA-XXX Migration: Short description of the change
# Date: YYYY-MM-DD
# Author: Name / ticket reference

def up
  # Implement the data change here.
  # Use ActiveRecord directly. Wrap in a transaction if multiple records are affected.
  # Log progress for visibility.
  ActiveRecord::Base.transaction do
    Model.where(condition: true).find_each do |record|
      record.update!(field: new_value)
      puts "Updated record id=#{record.id}"
    end
  end

  puts "up: completed successfully"
end

def verify
  # Validate that the change produced the expected state.
  # Raise if verification fails so the runner knows something is wrong.
  count = Model.where(field: new_value).count
  raise "verify failed: expected N records, got #{count}" unless count == EXPECTED_COUNT

  puts "verify: #{count} records in expected state — OK"
end

def rollback
  # Reverse the change applied in up.
  # Must be idempotent: safe to run multiple times.
  ActiveRecord::Base.transaction do
    Model.where(field: new_value).find_each do |record|
      record.update!(field: original_value)
      puts "Rolled back record id=#{record.id}"
    end
  end

  puts "rollback: completed successfully"
end

# Entry point — called explicitly by the runner
up
```

### Execution Process

1. **Commit** the script in a PR under the corresponding DATA-XXX ticket
2. **Review** the script in code review — verify `up`, `verify`, and `rollback` before merging
3. **Merge** the PR to `development`
4. **Execute** manually in the target environment:
   ```bash
   rails runner lib/data_scripts/DATA-XXX_YYYY-MM-DD_short-description.rb
   ```
5. **Verify** the result immediately after execution:
   ```bash
   # Run only the verify method (comment out the `up` call at the bottom first)
   rails runner lib/data_scripts/DATA-XXX_YYYY-MM-DD_short-description.rb
   ```
6. **Keep** the script in the repository permanently — it serves as a historical record

### Best Practices

- **Wrap in transactions**: use `ActiveRecord::Base.transaction` for any multi-record change
- **Log progress**: print record IDs or counts so the operator can see what is happening
- **Use `find_each`**: never load the full dataset into memory (`Model.all.each` is prohibited)
- **Validate before writing**: check preconditions at the top of `up` and raise early if they are not met
- **Make rollback idempotent**: running rollback twice must produce the same result as running it once
- **Never hardcode environment-specific values**: use `ENV.fetch` or query the DB to resolve IDs at runtime
- **Test locally first**: run the script in development against a representative dataset before production

---

## Cross-project Changes

When implementing a ticket requires changes to a **related project** (e.g., a frontend ticket needs a new backend endpoint, or a backend ticket requires a frontend consumer update), follow this workflow before creating a new branch in the related project.

### Decision Workflow

1. Navigate to the related project's local directory:
   ```bash
   cd <related_project_local_path>
   ```

2. Check for existing active branches for the same ticket or related work:
   ```bash
   git fetch origin
   git branch -r | grep -v HEAD
   ```

3. **If an active branch exists** for the related ticket:
   - Checkout the existing branch:
     ```bash
     git checkout <existing-branch-name>
     # or for a remote branch not yet local:
     git checkout -b <existing-branch-name> origin/<existing-branch-name>
     ```
   - Make your changes and commit on that branch:
     ```bash
     git add <specific files>
     git commit -m "feat(scope): cross-project changes for FEAT-XXX"
     git push origin <existing-branch-name>
     ```
   - Reference the cross-project commit in your PR description.

4. **If NO active branch exists** for the related work:
   - Do NOT create a new branch directly. Instead, create a separate ticket via the PM Agent:
     ```bash
     curl -X POST http://localhost:3000/api/v1/tickets/generate \
       -H "Content-Type: application/json" \
       -H "X-Api-Key: $PM_AGENT_API_KEY" \
       -d '{
         "idea": "Implement <describe the required change> required as prerequisite for <current ticket ID>",
         "project": "<related_project_name>",
         "ticket_type": "feat"
       }'
     ```
   - Document the prerequisite in your current PR description:
     ```
     ## Prerequisites
     - [ ] <Related Project Name>: <ticket-id> — <description of the required change>
     ```
   - The current ticket should NOT be merged until the prerequisite ticket is completed.

### Rules

- **Never create a duplicate branch** in a related project for work already tracked in an existing branch.
- **Always check `git branch -r`** before creating any cross-project branch.
- **Always document dependencies** in the PR description when a prerequisite ticket is created.
- The 1-ticket = 1-branch rule applies per project — a cross-project commit on an existing branch is the correct approach, not a new branch.

---

## If the Ticket Was Returned to Back to Dev

1. Fetch the PR comments:
   ```bash
   curl -s "http://localhost:3000/api/v1/tickets/{id}/review_comments" \
     -H "X-Api-Key: {API_KEY}"
   ```
2. Read every comment and make all requested changes
3. Linter 0 offenses → security OK
4. New commit on the SAME branch — do NOT create a new branch:
   ```bash
   git add . && git commit -m "fix(scope): description of change based on review comments"
   git push origin <current-branch>
   ```
5. Call `/complete` again with the same ticket ID

### ⚠️ Definition of Done (Back to Dev)
- [ ] Changes are on the original branch
- [ ] `git push` executed successfully
- [ ] `/complete` returned success

**If any of these points were not met, the work is incomplete. There is no valid intermediate state.**