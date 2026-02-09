# Etsy Integration Example

This is an example of well-structured integration documentation. Use this as a reference when documenting other third-party integrations.

## What Makes This Good Documentation

### 1. Clear Overview
The document starts with a high-level overview that explains:
- What the integration does
- Why it exists
- How it fits into the overall system

### 2. Comprehensive Model Documentation
Each model is documented with:
- Purpose and responsibilities
- Key attributes with types
- Associations to other models
- Enum values (when applicable)

### 3. Detailed Service Documentation
Services are explained with:
- File locations
- Responsibilities
- Key features
- Different modes of operation (e.g., Live vs Mock)

### 4. Authentication Details
The authentication section covers:
- What auth mechanism is used (OAuth2 with PKCE)
- How to set up locally vs production
- Where credentials are stored
- Token lifecycle

### 5. Frontend Integration
Frontend components are documented with:
- File locations
- User workflows
- State management approach
- Key features

### 6. API Endpoints
All HTTP endpoints are listed with:
- HTTP method
- Path
- Purpose

### 7. Testing Coverage
Test files are referenced:
- Unit tests for services
- Controller tests
- System/integration tests

## Structure to Follow

```markdown
# Feature Name Integration

## Overview
Brief description

## Core Models
### ModelName
- Attributes
- Associations
- Purpose

## Services
### ServiceName
- Location
- Responsibilities
- Key methods

## Authentication
- Mechanism
- Setup
- Credentials

## Controllers/API
- Endpoints listed

## Frontend
- Components
- Workflows

## Testing
- Test file locations

## Common Issues (optional)
- Known problems and solutions
```

## Anti-Patterns to Avoid

❌ **Don't:**
- Write giant walls of code without explanation
- Leave out file locations
- Skip testing information
- Forget to update when code changes
- Use vague descriptions like "handles stuff"

✅ **Do:**
- Explain the "why" not just the "what"
- Include concrete file paths
- Document all public APIs
- Keep it concise but complete
- Update when refactoring

## See Also

The actual Etsy integration documentation:
- `file:///run/media/ricky/4tb/repos/3dprinting/PrintMines/.agent/context/etsy-integration-and-orders.md`
