# Context Documenter Scripts

This directory contains scripts for managing the `.agent/context/` documentation.

## Available Scripts

### 1. `split_oversized_docs.rb`

Automatically splits large documentation files (>250 lines) into focused sub-documents.

**Usage:**
```bash
# Preview what would be split (no changes)
ruby .claude/skills/context-documenter/scripts/split_oversized_docs.rb --dry-run

# Split all oversized files
ruby .claude/skills/context-documenter/scripts/split_oversized_docs.rb

# Use custom threshold
ruby .claude/skills/context-documenter/scripts/split_oversized_docs.rb --threshold=300
```

**How it works:**
1. Scans `.agent/context/**/*.md` for files exceeding the line threshold
2. Identifies H2 headings (`## Section`) as logical split points
3. Creates a subdirectory named after the original file
4. Generates focused sub-documents for each major section
5. Creates `README.md` index with section summaries and navigation
6. Archives original file as `*.md.old`

**Example:**
```
Before:
  .agent/context/features/orders.md (500 lines)

After:
  .agent/context/features/orders/README.md          (index)
  .agent/context/features/orders/core-models.md
  .agent/context/features/orders/services.md
  .agent/context/features/orders/controllers.md
  .agent/context/features/orders.md.old             (archive)
```

**When to use:**
- Documentation file exceeds 250 lines
- Multiple topics mixed in one file
- Difficult to navigate or find specific information
- As part of regular documentation maintenance

**Filters:**
- Skips sections shorter than 20 lines (too small to be meaningful)
- Skips files with no clear H2 section structure
- Only processes `.md` files in `.agent/context/`

### 2. `analyze_feature.rb`

*(Not yet implemented)*

Analyzes a feature area to suggest documentation structure.

### 3. `validate_docs.rb`

*(Not yet implemented)*

Validates documentation for broken links and outdated code references.

## Workflow

**Typical documentation maintenance workflow:**

1. **Check for oversized files:**
   ```bash
   ruby .claude/skills/context-documenter/scripts/split_oversized_docs.rb --dry-run
   ```

2. **Review the preview** to see what would be split

3. **Run the split** (remove `--dry-run`):
   ```bash
   ruby .claude/skills/context-documenter/scripts/split_oversized_docs.rb
   ```

4. **Review the results:**
   - Check the new subdirectories
   - Read the generated README.md index files
   - Verify sections were split logically

5. **Clean up archives:**
   ```bash
   # If satisfied with results, delete .old files
   find .agent/context -name "*.md.old" -delete
   ```

6. **Commit changes:**
   ```bash
   git add .agent/context
   git commit -m "docs: split oversized documentation files for better readability"
   ```

## Best Practices

### Writing Documentation for Splitting

To ensure documentation splits cleanly:

1. **Use H2 headings** (`##`) for major sections:
   ```markdown
   ## Core Models
   ## Services
   ## Controllers / API Endpoints
   ```

2. **Keep sections focused** - each H2 section should cover one topic

3. **Make sections meaningful** - aim for 20+ lines per section

4. **Use descriptive headings** - "Core Models" not "Models", "API Endpoints" not "Endpoints"

5. **Cross-reference** - link to related sections in other files

### Maintaining Split Documentation

After splitting:

1. **Update specific sections** - edit the sub-documents, not the index
2. **Keep README current** - regenerate if section structure changes
3. **Monitor size** - if sub-documents exceed 250 lines, consider further splitting
4. **Use relative links** - `[See Services](./services.md)` for navigation

## Technical Details

**Language:** Ruby 3.x+

**Dependencies:** None (uses only Ruby stdlib)

**Files Modified:**
- Creates: `<original-basename>/` directory
- Creates: `<original-basename>/README.md` (index)
- Creates: `<original-basename>/<section-name>.md` (one per H2 section)
- Renames: `<original-file>.md` → `<original-file>.md.old`

**Safety:**
- `--dry-run` flag for preview
- Original files archived (not deleted)
- Only processes files in `.agent/context/`
- Filters out sections < 20 lines
