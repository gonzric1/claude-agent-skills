---
name: context-documenter
description: Creates or updates comprehensive documentation files in the .agent/context folder to help future agents understand features, integrations, and project architecture.
---

# Context Documenter

This skill helps you create and update documentation in the `.agent/context` folder. These documentation files serve as the knowledge base for future AI agents working on the codebase.

## When to Use This Skill

- After implementing a new feature or integration
- When significant changes are made to existing functionality
- When you need to document architectural decisions
- When updating or refactoring a major component
- When onboarding documentation is missing for a key area

## Documentation Philosophy

Context documentation should:
- **Be comprehensive but concise**: Include all necessary details without overwhelming
- **Focus on the "why"**: Explain architectural decisions and design patterns
- **Include practical examples**: Show code locations, API endpoints, and workflows
- **Stay current**: Update when the underlying code changes
- **Help future agents**: Write for someone who hasn't seen this code before

## Step-by-Step Instructions

### 1. Identify Documentation Scope
First, determine what needs to be documented:
- Is this a new feature, integration, or component?
- What existing documentation files might be affected?
- Should this be a new file or an update to an existing one?

### 2. Gather Information
Use `[[ @scripts/analyze_feature.rb ]]` to automatically analyze a feature area:
```bash
ruby .agent/skills/context-documenter/scripts/analyze_feature.rb <feature_name>
```

This script will:
- Find related files in the codebase
- Identify models, services, controllers, and components
- List relevant tests
- Suggest documentation structure

### 3. Choose Documentation Structure
Use one of the templates from `[[ @assets/ ]]`:
- **feature-integration.md**: For third-party integrations (Etsy, Bambu, etc.)
- **component-architecture.md**: For major components (fleet management, inventory, etc.)
- **technical-guide.md**: For technical how-tos and debugging guides
- **frontend-pattern.md**: For React/frontend patterns and conventions

### 4. Create or Update Documentation
Either:
- Create a new file in `.agent/context/` following the chosen template
- Update an existing file with the new information

### 5. Validate Documentation
Use `[[ @scripts/validate_docs.rb ]]` to check the documentation:
```bash
ruby .agent/skills/context-documenter/scripts/validate_docs.rb <doc_file>
```

This ensures:
- All referenced files exist
- Code examples are current
- Links are valid
- Structure is consistent

## Documentation Structure Guidelines

### File Naming
- Use lowercase with hyphens: `etsy-integration-and-orders.md`
- Be specific but concise: `printer-fleet-management.md`, not `printers.md`
- Group related docs in subdirectories when needed

### Standard Sections
Most documentation should include:

1. **Overview**: High-level description of the feature/component
2. **Core Models**: Database models and their relationships
3. **Services**: Business logic and service objects
4. **Controllers/API Endpoints**: HTTP endpoints and their purposes
5. **Frontend Components**: React components and workflows
6. **Authentication/Authorization**: Security considerations
7. **Testing**: Test files and coverage notes
8. **Deployment**: Production considerations
9. **Common Issues**: Known pitfalls and solutions

### Code References
When referencing code:
- Include file paths: `app/services/etsy/sync_service.rb`
- Show class/method names: `Etsy::SyncService#sync_orders`
- Link to specific line numbers for complex logic
- Include actual code snippets for critical algorithms

### Cross-References
Link to related documentation:
```markdown
See [Printer Fleet Management](file:///path/to/printer-fleet-management.md) for details.
```

## Common Documentation Patterns

### New Integration
Document:
- Third-party API details and authentication
- Service objects that wrap the API
- Data models and mappings
- Sync/webhook workflows
- Error handling strategies

### New Feature
Document:
- User-facing workflow
- Backend models and services
- Frontend components and state management
- API endpoints
- Test coverage

### Architectural Change
Document:
- What changed and why
- Migration path (if applicable)
- New patterns or conventions
- Impact on existing code

## Maintenance

### When to Update
Update documentation when:
- Adding new endpoints or methods
- Changing workflows or state machines
- Refactoring major components
- Fixing bugs that reveal gaps in understanding
- Adding new dependencies or integrations

### Review Checklist
Before finalizing documentation:
- [ ] All file paths are accurate
- [ ] Code examples are tested and current
- [ ] Links to other docs work
- [ ] Technical terms are explained
- [ ] Common pitfalls are documented
- [ ] Testing approach is clear
- [ ] Deployment notes are included (if applicable)

## Examples

See `[[ @references/ ]]` for examples of well-documented features:
- `etsy-integration-example.md`: Shows how to document a third-party integration
- `component-example.md`: Shows how to document a major component
- `frontend-example.md`: Shows how to document React patterns

## Technical Details

- **Scripts**:
  - `analyze_feature.rb`: Analyzes codebase to suggest documentation structure
  - `validate_docs.rb`: Validates documentation for broken links and outdated references
- **Templates**: Located in `assets/` directory
- **References**: Example documentation files in `references/` directory
