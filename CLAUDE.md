# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

listmonk is a standalone, self-hosted newsletter and mailing list manager written in Go with a Vue.js frontend. It's a single binary application that uses PostgreSQL as its data store.

- **Backend**: Go (using Echo framework)
- **Frontend**: Vue 2.7 with Buefy/Bulma UI
- **Database**: PostgreSQL with custom SQL queries
- **Build System**: Make + stuffbin for asset embedding

## Build and Development Commands

### Backend Development

```bash
# Build the backend binary
make build

# Run backend in dev mode (loads frontend from disk at frontend/dist)
make run

# Run Go tests
make test

# Build production binary with embedded assets
make dist
```

### Frontend Development

```bash
# Install frontend dependencies
cd frontend && yarn install

# Run frontend dev server (proxies API calls to :9000)
make run-frontend
# Frontend runs on http://localhost:8080

# Build frontend for production
make build-frontend

# Build the email builder component
make build-email-builder
```

### Full Development Environment

```bash
# Setup local Docker dev environment (includes PostgreSQL + Mailhog)
make init-dev-docker

# Start full dev stack (PostgreSQL, Mailhog, frontend, backend)
make dev-docker
# Access at http://localhost:8080

# Tear down Docker dev environment
make rm-dev-docker

# Run backend with Docker config
make run-backend-docker
```

### Database Operations

```bash
# Generate config file
./listmonk --new-config

# Install/setup database schema
./listmonk --install

# Upgrade existing database (idempotent)
./listmonk --upgrade
```

## Architecture

### Backend Structure

**cmd/** - Main application entry point and HTTP handlers
- `main.go` - App initialization, contains the `App` struct with all global components
- `handlers.go` - HTTP middleware and handler registration
- Individual handler files for each domain (`campaigns.go`, `subscribers.go`, `lists.go`, etc.)

**internal/** - Core business logic organized by domain
- `core/` - Core business logic layer (campaigns, subscribers, lists, templates, etc.)
- `manager/` - Campaign manager that handles email sending and queue management
- `messenger/` - Messenger implementations (email, postback)
- `bounce/` - Bounce handling (mailbox polling, webhook handlers for SES, SendGrid, etc.)
- `media/` - Media/file storage (filesystem, S3 providers)
- `auth/` - Authentication and session management (supports OIDC)
- `subimporter/` - Subscriber import/CSV handling
- `migrations/` - Database migration files organized by version
- `i18n/` - Internationalization

**models/** - Data models and types used across the app

**queries/** - SQL query files (loaded via goyesql)
- Organized by domain: `campaigns.sql`, `subscribers.sql`, `lists.sql`, etc.

### Frontend Structure

**frontend/src/**
- `main.js` - Vue app initialization, router, store setup
- `router/` - Vue Router configuration
- `store/` - Vuex state management
- `views/` - Page-level Vue components
- `components/` - Reusable Vue components

**frontend/email-builder/** - Separate TypeScript/Vue visual email builder
- Built independently and copied to `frontend/public/static/email-builder`

### Key Architectural Patterns

1. **SQL-first approach**: All database queries are in `.sql` files under `queries/`, loaded via goyesql
2. **stuffbin asset embedding**: Static assets (SQL, frontend dist, i18n, templates) are embedded into the binary using stuffbin
3. **Manager pattern**: The `manager.Manager` handles campaign execution, email queuing, and worker pool management
4. **Messenger interface**: Email sending is abstracted through the `Messenger` interface allowing different providers
5. **Core business logic separation**: `internal/core` contains pure business logic, `cmd/` contains HTTP handlers that call core

### Database Schema

PostgreSQL with custom enums and tables:
- `subscribers` - Subscriber data with JSONB attributes
- `lists` - Mailing lists (public, private, temporary)
- `subscriber_lists` - Many-to-many subscription relationships
- `campaigns` - Email campaigns with status tracking
- `campaign_lists` - Campaign to list associations
- `templates` - Email templates (campaign, transactional, visual)
- `media` - Uploaded media files
- `bounces` - Bounce records with soft/hard/complaint types
- `users` - User accounts with role-based permissions
- `roles` - Permission-based access control

## Important Development Notes

### Backend

- **SQL queries**: Modify queries in `queries/*.sql` files, not in Go code
- **Configuration**: Uses koanf for config management, loads from `config.toml` and env vars
- **Database migrations**: Located in `internal/migrations/`, named by version (e.g., `v4.0.0.go`)
- **Static assets**: Modified static files must be re-embedded via `make dist`
- **Messenger configuration**: Email messenger settings in `config.toml` under `[smtp]` section

### Frontend

- **Vue 2.7**: Uses Options API, Vuex for state, Vue Router for navigation
- **Buefy**: UI component library based on Bulma CSS
- **API client**: Axios-based client in `src/api/`
- **Development**: Hot-reload enabled, API proxied to backend on `:9000`
- **Email builder**: Separate TypeScript project, must be built before frontend build

### Database

- **Connection pooling**: Configured in `config.toml` under `[db]`
- **Transactions**: Use `tx.go` handlers for transactional operations
- **JSONB attributes**: Subscribers have flexible JSONB `attribs` field
- **Indexing**: Extensive indexing on status fields and email lookups

### Testing and Quality

- **Go tests**: Run with `make test` or `go test ./...`
- **Frontend linting**: `yarn lint` in frontend directory (runs on prebuild)
- **Cypress E2E tests**: Available in `frontend/cypress/`

## Configuration

- `config.toml.sample` - Sample configuration with all options
- Environment variables: Prefix with `LISTMONK_` (e.g., `LISTMONK_app__address`)
- Database connection: `[db]` section in config.toml
- SMTP settings: `[smtp]` section in config.toml
- Media storage: `[media]` section (filesystem or S3)

## Docker Development

The `dev/` directory contains a complete Docker Compose setup for local development:
- PostgreSQL database
- Mailhog (mock SMTP server with web UI)
- Backend Go app (with volume mount for live changes)
- Frontend Node.js dev server (with hot reload)

Use `make dev-docker` for containerized development, `make run` + `make run-frontend` for local development.

## Third-Party Integrations

- **Bounce handlers**: Webhooks for SES, SendGrid, Postmark, ForwardEmail
- **OIDC**: Authentication via external OIDC providers
- **S3-compatible storage**: For media uploads
- **CAPTCHA**: Support for CAPTCHA challenges on public forms
