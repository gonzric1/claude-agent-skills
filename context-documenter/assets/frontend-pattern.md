# {{PATTERN_NAME}}

## Overview
Brief description of the frontend pattern, when to use it, and why it's important.

## Problem Statement
What problem does this pattern solve? What pain points does it address?

## Solution
How this pattern solves the problem.

## Implementation

### File Structure
```
app/javascript/
  components/
    feature/
      ComponentName.tsx
      ComponentName.test.tsx
      types.ts
      hooks/
        useFeature.ts
```

### Code Example

```typescript
// Example implementation
import React from 'react';

interface Props {
  // Define props
}

export const ComponentName: React.FC<Props> = ({ prop1, prop2 }) => {
  // Implementation
  return (
    <div>
      {/* Component markup */}
    </div>
  );
};
```

## When to Use

✅ **Use this pattern when:**
- Condition 1
- Condition 2
- Condition 3

❌ **Avoid this pattern when:**
- Condition 1
- Condition 2
- Condition 3

## Best Practices

### Do's
- ✅ Best practice 1
- ✅ Best practice 2
- ✅ Best practice 3

### Don'ts
- ❌ Anti-pattern 1
- ❌ Anti-pattern 2
- ❌ Anti-pattern 3

## Testing

How to test components using this pattern:

```typescript
import { render, screen } from '@testing-library/react';
import { ComponentName } from './ComponentName';

describe('ComponentName', () => {
  it('should render correctly', () => {
    render(<ComponentName />);
    // Assertions
  });
});
```

## Common Pitfalls

### Pitfall 1: Description
**Problem**: What goes wrong
**Solution**: How to avoid it

### Pitfall 2: Description
**Problem**: What goes wrong
**Solution**: How to avoid it

## Examples in Codebase

Real examples of this pattern in use:
- `app/javascript/components/example1/Component.tsx`
- `app/javascript/components/example2/Component.tsx`

## Performance Considerations

- How this pattern affects performance
- Optimization strategies
- When to use React.memo, useMemo, useCallback

## TypeScript Considerations

- Type definitions needed
- Generic patterns
- Type safety tips

## Related Patterns

- [Related Pattern 1](file:///path/to/pattern1.md)
- [Related Pattern 2](file:///path/to/pattern2.md)

## References

- External documentation links
- Blog posts
- Official React/TypeScript docs
