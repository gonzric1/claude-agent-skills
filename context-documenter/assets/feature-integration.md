# {{FEATURE_NAME}} Integration

## Overview
Brief description of the third-party integration, what it does, and why it's important.

## Core Models

### 1. `ModelName`
Description of the model.
*   **Attributes**: List key attributes
*   **Associations**: Relationships to other models
*   **Purpose**: Why this model exists

## Services

### 1. `Namespace::ServiceName`
Description of the service.
*   **Location**: `app/services/path/to/service.rb`
*   **Responsibilities**: What this service does
*   **Key Methods**: Important public methods

### 2. `Namespace::ClientService`
API client wrapper.
*   **Location**: `app/services/path/to/client.rb`
*   **Authentication**: How it authenticates
*   **Endpoints**: Key API endpoints used

## Authentication

Describe the authentication mechanism (API keys, OAuth, etc.)

### Setup & Deployment
- **Local**: How to set up locally
- **Production**: Production deployment notes
- **Credentials**: Where secrets are stored

## Controllers/API Endpoints

### 1. `NamespaceController`
*   `GET /path`: Description
*   `POST /path`: Description
*   `PATCH /path/:id`: Description

## Frontend Components

### 1. `ComponentName`
*   **Location**: `app/javascript/components/path/to/Component.tsx`
*   **Purpose**: What it does
*   **Features**: Key features

## Background Jobs

### 1. `Namespace::SyncJob`
*   **Purpose**: Periodic sync from third-party
*   **Schedule**: How often it runs
*   **Error Handling**: What happens on failure

## Configuration

Environment variables needed:
- `API_KEY`: Purpose
- `API_SECRET`: Purpose
- `WEBHOOK_SECRET`: Purpose

## Testing

*   **Integration**: `test/services/namespace/service_test.rb`
*   **Controller**: `test/controllers/namespace_controller_test.rb`
*   **System**: `test/system/feature_test.rb`

## Common Issues

### Issue 1: Description
**Symptoms**: What you see
**Cause**: Why it happens
**Solution**: How to fix

## Related Documentation

- [Other Related Feature](file:///path/to/other-feature.md)
