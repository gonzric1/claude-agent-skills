# Beads Ticket Template

This template shows how to create tickets using the beads CLI.

## Basic Creation

```bash
bd create "Clear Actionable Title" \
  --priority 2 \
  --labels "ticket" \
  --description "Description of the task" \
  --acceptance "Acceptance criteria"
```

## Full Example

```bash
bd create "Add user authentication endpoint" \
  --priority 2 \
  --labels "ticket,backend,auth" \
  --description "$(cat <<'EOF'
## Context & Problem
The API currently has no authentication. Users need to be able to log in
to access protected resources.

## Requirements
1. Create POST /api/auth/login endpoint
2. Accept email and password in request body
3. Return JWT token on successful authentication
4. Return 401 on invalid credentials

## Files Affected
- app/controllers/auth_controller.rb
- config/routes.rb
- spec/requests/auth_spec.rb

## Testing
- [ ] Add request specs for login endpoint
- [ ] Test successful login returns JWT
- [ ] Test invalid credentials returns 401
- [ ] Test missing fields returns 400
EOF
)" \
  --acceptance "$(cat <<'EOF'
- [ ] POST /api/auth/login accepts email/password
- [ ] Returns JWT token on success
- [ ] Returns 401 on invalid credentials
- [ ] Request specs pass
- [ ] YARD documentation added
EOF
)"
```

## Priority Reference

| Priority | Label | Use Case |
|----------|-------|----------|
| 0 | critical | Security, data loss, critical bugs |
| 1 | major | Core functionality broken |
| 2 | moderate | Significant issue with workaround |
| 3 | ticket | Standard feature work |
| 4 | nit | Style, naming, minor refactors |

## Setting Dependencies

After creating tickets, set dependencies:

```bash
# PROJ-2 is blocked by PROJ-1 (PROJ-1 must complete first)
bd dep add PROJ-2 PROJ-1
```

## Quick Capture

For rapid issue creation:

```bash
bd q "Quick description of the task"
```
