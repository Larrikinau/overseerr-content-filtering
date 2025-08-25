# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

**Overseerr Content Filtering** is a specialized fork of Overseerr that adds admin-controlled content rating filters for family-safe media management. This is a full-stack TypeScript application built with:

- **Frontend**: Next.js 12.3.4 with React 18.2.0, TailwindCSS
- **Backend**: Express.js server with TypeScript
- **Database**: SQLite (default) with TypeORM migrations
- **API Integration**: The Movie Database (TMDb), Plex, Radarr, Sonarr
- **Containerization**: Docker with multi-stage builds

### Key Content Filtering Features

This fork's primary differentiation is **admin-only content rating control**:
- Administrators can set per-user content rating limits (G through NC-17 for movies, TV-Y through TV-MA for TV)
- Users cannot see or modify their own rating restrictions
- Content filtering is applied across all discovery, search, and browse endpoints
- Default family-safe settings with PG-13/TV-PG limits for new users

## Development Commands

### Essential Development Commands

```bash
# Development server with hot reload
yarn dev

# Build entire application (frontend + server)
yarn build

# Start production server
yarn start

# Lint all TypeScript/TSX files
yarn lint

# Format all files with Prettier
yarn format

# Type checking
yarn typecheck
```

### Database & Migration Commands

```bash
# Generate new TypeORM migration
yarn migration:generate src/migration/MigrationName

# Create empty migration file
yarn migration:create src/migration/MigrationName

# Run pending migrations
yarn migration:run
```

### Testing Commands

```bash
# Open Cypress test runner
yarn cypress:open

# Prepare test database
yarn cypress:prepare

# Build and prepare for Cypress tests
yarn cypress:build
```

### Build Components

```bash
# Build server only (TypeScript compilation)
yarn build:server

# Build frontend only (Next.js)
yarn build:next
```

## Architecture

### High-Level Structure

```
├── server/              # Express.js backend
│   ├── api/             # External API integrations (TMDb, Plex, etc.)
│   ├── routes/          # Express route handlers
│   ├── entity/          # TypeORM database models
│   ├── lib/             # Core business logic (notifications, settings, permissions)
│   └── middleware/      # Express middleware
├── src/                 # Next.js frontend
│   ├── components/      # React components
│   ├── pages/           # Next.js pages/routes
│   └── i18n/           # Internationalization
├── public/              # Static assets
└── cypress/             # E2E tests
```

### Key Architectural Patterns

1. **Content Filtering Integration**: Content rating filtering is implemented at the API integration level in `server/api/themoviedb/index.ts`. The `createTmdbWithRegionLanguage()` function in `server/routes/discover.ts` passes user rating preferences to all TMDb API calls.

2. **User Settings Architecture**: Content filtering settings are stored in the `UserSettings` entity with columns:
   - `maxMovieRating`: Maximum allowed movie rating (G, PG, PG-13, R, NC-17)
   - `maxTvRating`: Maximum allowed TV rating (TV-Y through TV-MA)  
   - `tmdbSortingMode`: Discovery mode ("curated" for enhanced quality filtering)
   - `curatedMinVotes`/`curatedMinRating`: Quality thresholds for curated discovery

3. **Permission System**: Uses a bitmask-based permission system. Content rating controls are admin-only - regular users cannot view or modify their rating restrictions.

4. **Database Migrations**: The application automatically runs TypeORM migrations in production/Docker environments. Migration files are in `server/migration/` and executed during startup.

5. **API Integration Layer**: Centralized external API handling through `server/api/` with specific integrations for:
   - TMDb (primary content metadata)
   - Plex (media server integration)
   - Radarr/Sonarr (download client integration)
   - Various notification services

### Frontend Architecture

- **Next.js App Router**: Uses pages-based routing in `src/pages/`
- **Component Organization**: Hierarchical component structure in `src/components/` with common UI components in `src/components/Common/`
- **State Management**: Uses SWR for API data fetching and caching
- **Styling**: TailwindCSS with custom themes and responsive design
- **Internationalization**: React-Intl with locale files in `src/i18n/`

### Backend Architecture

- **Express.js Server**: Main server entry point in `server/index.ts` with comprehensive middleware setup
- **TypeORM Integration**: Database models in `server/entity/` with automatic migration support
- **Route Organization**: RESTful API routes in `server/routes/` organized by feature area
- **External API Abstraction**: Wrapper classes in `server/api/` for external services
- **Business Logic**: Core application logic in `server/lib/` (notifications, permissions, settings)

## Development Environment Setup

### Prerequisites

- Node.js 18+ and Yarn
- SQLite (for default database)
- Optional: Docker for containerized development

### Environment Variables

Critical environment variables for development:

```bash
# Required for movie/TV metadata
TMDB_API_KEY=your_tmdb_key

# Database (optional, defaults to SQLite)
DATABASE_URL=sqlite:config/db/db.sqlite3

# Development settings
NODE_ENV=development
PORT=5055
LOG_LEVEL=info

# Migration control
RUN_MIGRATIONS=true
```

### Docker Development

The project includes comprehensive Docker support:

```bash
# Build local Docker image
docker build -t overseerr-content-filtering:local .

# Run with development settings
docker run -p 5055:5055 \
  -e NODE_ENV=development \
  -e TMDB_API_KEY=your_key \
  -v ./config:/app/config \
  overseerr-content-filtering:local
```

## Testing Strategy

### End-to-End Testing with Cypress

- Test configuration in `cypress.config.ts`
- Test user credentials configured for admin and regular user scenarios
- Base URL defaults to `localhost:5055`
- Run `yarn cypress:prepare` to set up test database before running tests

### Type Safety

- Comprehensive TypeScript configuration in `tsconfig.json`
- Path aliases configured for `@server/*` and `@app/*`
- Strict TypeScript settings with decorator support for TypeORM

## Migration and Deployment

### Database Migrations

The application uses TypeORM migrations with automatic execution in production:

- Migrations are stored in `server/migration/`
- Production/Docker environments automatically run pending migrations on startup
- Development environments require `RUN_MIGRATIONS=true` or manual execution
- Critical content filtering columns are verified post-migration

### Docker Production Deployment

Multi-stage Docker build optimized for production:

1. **Build Stage**: Compiles TypeScript, builds Next.js, installs dependencies
2. **Production Stage**: Minimal Alpine image with only runtime dependencies
3. **Security**: Runs as non-root user, minimal attack surface
4. **Migration Support**: Automatic database migration on container startup

## Content Filtering Implementation

### Admin-Only Control

Content filtering is designed with admin-exclusive control:

- Only users with admin permissions can modify content rating settings
- Regular users cannot view their own rating restrictions
- Settings are configured per-user in the admin interface under Users > Edit User > General tab

### Technical Implementation

Content filtering is applied at multiple levels:

1. **API Level**: TMDb API calls include rating filters based on user settings
2. **Discovery Routes**: `server/routes/discover.ts` applies user-specific filtering
3. **Database Level**: User settings stored in `user_settings` table with rating columns
4. **Frontend**: Rating-restricted content is filtered from all browse/search results

### Quality-Based Discovery

Enhanced "curated" discovery mode with configurable thresholds:

- `curatedMinVotes`: Minimum vote count required (default: 3000)
- `curatedMinRating`: Minimum rating required (default: 6.0)
- Applied in addition to content rating filters for higher-quality recommendations
