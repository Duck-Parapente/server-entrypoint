# Server Entrypoint

This directory contains the main reverse proxy configuration that serves as the entrypoint for all Duck Parapente services.

## Architecture

The setup uses **Caddy** as a reverse proxy to route incoming requests to different backend services based on the domain name. All services communicate through a shared Docker network called `proxy`.

## Services Exposed

### 1. Biplace Booking - Production
- **URL**: `bb-backend-prod.duckparapente.fr`
- **Backend**: `bb-prod-caddy:80`
- **Description**: Production environment for the Biplace Booking application
- **Source**: See the `biplace-booking` repository for backend implementation

### 2. Biplace Booking - Staging
- **URL**: `bb-backend-staging.duckparapente.fr`
- **Backend**: `bb-staging-caddy:80`
- **Description**: Staging environment for testing new features before production deployment
- **Source**: See the `biplace-booking` repository for backend implementation

### 3. Vaultwarden (Password Manager)
- **URL**: `vault.duckparapente.fr`
- **Backend**: `vaultwarden:80`
- **Description**: Self-hosted Bitwarden-compatible password manager
- **Internal Port**: 8443 (mapped to container port 80)
- **Data Storage**: `./data` directory
- **Configuration**:
  - Signups disabled (invite-only)
  - Admin token protected
  - Invitations enabled

## How It Works

1. **Caddy Reverse Proxy** (`entrypoint_caddy`):
   - Listens on ports 80 (HTTP) and 443 (HTTPS)
   - Automatically handles SSL/TLS certificates via Let's Encrypt
   - Routes requests based on domain names defined in `Caddyfile`
   - Forwards appropriate headers (Real IP, Forwarded-For, Protocol)
   - Logs all requests in JSON format to stdout

2. **Docker Network** (`proxy`):
   - External network shared between this entrypoint and backend services
   - Allows containers to communicate using service names as hostnames
   - Must be created before starting services: `docker network create proxy`

3. **Request Flow**:
   ```
   Internet → Caddy (ports 80/443)
            ↓
            └─ Domain-based routing
               ├─ bb-backend-prod.duckparapente.fr → bb-prod-caddy:80
               ├─ bb-backend-staging.duckparapente.fr → bb-staging-caddy:80
               └─ vault.duckparapente.fr → vaultwarden:80
   ```

## Biplace Booking Backend

The Biplace Booking application is a separate project located in the `biplace-booking` repository. Each environment (production and staging) runs its own instance with:

- **Backend**: NestJS API server
- **Frontend**: Nuxt.js application
- **Database**: PostgreSQL with Prisma ORM
- **Internal Reverse Proxy**: Caddy (routes between frontend and backend)

The backend services (`bb-prod-caddy` and `bb-staging-caddy`) are defined in the `biplace-booking` repository's infrastructure setup and must be running on the same Docker `proxy` network.

## Setup

1. Create the shared Docker network:
   ```bash
   docker network create proxy
   ```

2. Start the services:
   ```bash
   docker-compose up -d
   ```

3. Ensure backend services from `biplace-booking` are running and connected to the `proxy` network.

## Data Persistence

- **Vaultwarden**: Data is stored in `./data` directory
  - `db.sqlite3`: Main database
  - `db.sqlite3-shm`, `db.sqlite3-wal`: SQLite write-ahead log files
  - `tmp/`: Temporary files

## Logs

View Caddy logs:
```bash
docker logs -f caddy-entrypoint
```

View Vaultwarden logs:
```bash
docker logs -f vaultwarden
```

## Security Notes

- All traffic is automatically encrypted with HTTPS via Caddy's automatic HTTPS
- Vaultwarden is configured with signups disabled
- Admin access to Vaultwarden requires the `ADMIN_TOKEN` environment variable
- Invitations can be sent from the admin panel
