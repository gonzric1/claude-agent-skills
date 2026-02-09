# Context Documenter Skill

A skill for creating and maintaining comprehensive documentation in the `.agent/context` folder.

## Quick Start

### Analyze a Feature
```bash
ruby .agent/skills/context-documenter/scripts/analyze_feature.rb etsy
```

This will scan the codebase and suggest:
- Related models, services, controllers, components
- Recommended documentation structure
- Suggested filename

### Validate Documentation
```bash
ruby .agent/skills/context-documenter/scripts/validate_docs.rb .agent/context/etsy-integration.md
```

This checks for:
- Broken file references
- Broken documentation links
- Placeholder text
- Markdown structure issues

## Directory Structure

```
context-documenter/
├── SKILL.md                 # Main skill instructions
├── README.md                # This file
├── scripts/
│   ├── analyze_feature.rb   # Analyzes codebase for documentation
│   └── validate_docs.rb     # Validates existing documentation
├── assets/
│   ├── feature-integration.md    # Template for integrations
│   ├── component-architecture.md # Template for components
│   ├── frontend-pattern.md       # Template for frontend patterns
│   └── technical-guide.md        # Template for how-tos
└── references/
    └── etsy-integration-example.md  # Example of good docs
```

## Templates

Choose the appropriate template from `assets/`:

- **feature-integration.md**: For third-party integrations (Etsy, Bambu, Stripe, etc.)
- **component-architecture.md**: For major components (fleet management, inventory, etc.)
- **frontend-pattern.md**: For React/frontend patterns
- **technical-guide.md**: For debugging guides and how-tos

## Best Practices

1. **Run analyze_feature.rb first** - It saves time by finding all related files
2. **Choose the right template** - Don't force a pattern if it doesn't fit
3. **Keep it current** - Update docs when you refactor code
4. **Validate before committing** - Run validate_docs.rb to catch errors
5. **Link related docs** - Cross-reference other context files

## Workflow Example

```bash
# 1. Analyze the feature
ruby .agent/skills/context-documenter/scripts/analyze_feature.rb bambu

# 2. Copy appropriate template
cp .agent/skills/context-documenter/assets/feature-integration.md \
   .agent/context/bambu-mqtt-integration.md

# 3. Fill in the template with real information

# 4. Validate the documentation
ruby .agent/skills/context-documenter/scripts/validate_docs.rb \
   .agent/context/bambu-mqtt-integration.md

# 5. Fix any errors and commit
```

## When to Document

- ✅ After implementing a new feature
- ✅ After significant refactoring
- ✅ When adding a third-party integration
- ✅ When establishing a new pattern
- ✅ When fixing complex bugs

## Contributing

If you create new templates or improve the scripts, make sure to:
1. Update this README
2. Add examples to `references/`
3. Test the scripts on real features
4. Document any new conventions
