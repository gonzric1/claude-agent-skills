# {{COMPONENT_NAME}} Architecture

## Overview
High-level description of the component, its purpose, and how it fits into the overall application.

## Architecture Diagram
```
[Optional: ASCII art or description of component architecture]
  Frontend (React)
       ↓
  Controllers
       ↓
  Services/Jobs
       ↓
  Models
       ↓
  External Systems (if applicable)
```

## Core Models

### 1. `ModelName`
*   **Purpose**: Why this model exists
*   **Attributes**: Key attributes
*   **Validations**: Important validations
*   **Associations**: 
    *   `belongs_to :parent`
    *   `has_many :children`
*   **Scopes**: Useful query scopes
*   **Methods**: Key instance/class methods

## Services & Business Logic

### 1. `Namespace::ServiceName`
*   **Location**: `app/services/path/to/service.rb`
*   **Purpose**: What problem it solves
*   **Dependencies**: What it depends on
*   **Key Methods**:
    *   `method_name(args)`: What it does

## State Management

### State Machine (if applicable)
States: `state1`, `state2`, `state3`

Transitions:
- `state1` → `state2`: When X happens
- `state2` → `state3`: When Y happens

## Controllers/Routes

### 1. `ComponentController`
*   **Location**: `app/controllers/component_controller.rb`
*   **Routes**:
    *   `GET /path`: Purpose
    *   `POST /path`: Purpose
    *   `PATCH /path/:id`: Purpose
    *   `DELETE /path/:id`: Purpose

## Frontend Architecture

### Components
*   **Location**: `app/javascript/components/component/`
*   **State Management**: How state is managed (Context, Props, etc.)
*   **Key Components**:
    *   `MainComponent`: Purpose
    *   `ChildComponent`: Purpose

### API Integration
How the frontend communicates with the backend:
- Endpoints used
- Error handling
- Optimistic updates (if applicable)

## Background Jobs

### 1. `JobName`
*   **Purpose**: What it does
*   **Triggered By**: When/how it runs
*   **Frequency**: How often

## Database Schema

Key tables and their relationships:
```
table_name
  - column1: type (constraints)
  - column2: type (constraints)
  - foreign_key_id: references(other_table)
```

## WebSockets/Real-time (if applicable)

How real-time updates work:
- Channels used
- Events broadcast
- Client subscriptions

## Testing Strategy

### Unit Tests
*   `test/models/model_test.rb`
*   `test/services/service_test.rb`

### Integration Tests
*   `test/controllers/controller_test.rb`

### System Tests
*   `test/system/component_test.rb`

## Performance Considerations

- Potential N+1 queries and how to avoid them
- Caching strategy
- Background processing
- Database indexing

## Common Workflows

### Workflow 1: User Action
1. User does X
2. Frontend sends request to Y
3. Backend processes via Z
4. Result is A

## Security Considerations

- Authorization checks
- Input validation
- Data sanitization

## Deployment Notes

- Migrations needed
- Environment variables
- External dependencies

## Related Documentation

- [Related Component](file:///path/to/related.md)
