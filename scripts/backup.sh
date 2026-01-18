#!/bin/bash
set -e

# ----------- PATH SETUP -----------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"

# ----------- BUILD VARIABLES -----------
DATE=$(date +%Y_%m_%d_%H%M%S)
BACKUP_DIR="/var/backups/server-entrypoint"
BIPLACE_BASE_DIR="/srv"

# ----------- BACKUP FUNCTIONS -----------

# Function to backup Vaultwarden data
backup_vaultwarden() {
    local VAULT_DATA_DIR="$SERVER_DIR/data"
    local VAULT_BACKUP_NAME="vaultwarden_${DATE}.tar.gz"
    local VAULT_BACKUP_FILE="$BACKUP_DIR/$VAULT_BACKUP_NAME"
    local VAULT_REMOTE="gdrive:backup_vaultwarden"
    
    echo ""
    echo "=== VAULTWARDEN BACKUP ==="
    if [ -d "$VAULT_DATA_DIR" ]; then
        echo "Backing up Vaultwarden data from: $VAULT_DATA_DIR"
        tar -czf "$VAULT_BACKUP_FILE" -C "$(dirname "$VAULT_DATA_DIR")" "$(basename "$VAULT_DATA_DIR")"
        
        echo "Uploading Vaultwarden backup to Google Drive..."
        rclone copy "$VAULT_BACKUP_FILE" "$VAULT_REMOTE"
        
        echo "Deleting remote Vaultwarden backups older than 30 days..."
        rclone delete "$VAULT_REMOTE" --min-age 30d
        
        echo "✓ Vaultwarden backup completed: $VAULT_BACKUP_FILE"
    else
        echo "⚠ Vaultwarden data directory not found: $VAULT_DATA_DIR"
    fi
}

# Function to backup a Biplace Booking environment
backup_biplace_env() {
    local ENV=$1
    
    echo ""
    echo "=== BIPLACE BOOKING ($ENV) BACKUP ==="
    
    local ENV_DIR="$BIPLACE_BASE_DIR/${ENV}-biplace"
    local ENV_FILE="$ENV_DIR/infra/.env"
    
    if [ ! -d "$ENV_DIR" ]; then
        echo "⚠ Environment directory not found: $ENV_DIR (skipping)"
        return 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        echo "⚠ Missing .env file at: $ENV_FILE (skipping)"
        return 1
    fi
    
    # Load environment variables in a subshell to avoid conflicts
    local POSTGRES_DB=$(grep -v '^#' "$ENV_FILE" | grep POSTGRES_DB | cut -d '=' -f2)
    local POSTGRES_USER=$(grep -v '^#' "$ENV_FILE" | grep POSTGRES_USER | cut -d '=' -f2)
    
    if [ -z "$POSTGRES_DB" ] || [ -z "$POSTGRES_USER" ]; then
        echo "⚠ Missing required variables in .env (POSTGRES_DB, POSTGRES_USER) (skipping)"
        return 1
    fi
    
    local CONTAINER="bb-${ENV}-postgres"
    local REMOTE="gdrive:backup_biplace_${ENV}"
    
    local DUMP_NAME="dump_${DATE}.sql"
    local LOCAL_FILE="$BACKUP_DIR/${ENV}_${DUMP_NAME}"
    local COMPRESSED_FILE="${LOCAL_FILE}.gz"
    
    local ENV_BACKUP_NAME="env_${DATE}.env"
    local LOCAL_ENV_FILE="$BACKUP_DIR/${ENV}_${ENV_BACKUP_NAME}"
    local COMPRESSED_ENV_FILE="${LOCAL_ENV_FILE}.gz"
    
    echo "Container:     $CONTAINER"
    echo "DB User:       $POSTGRES_USER"
    echo "DB Name:       $POSTGRES_DB"
    echo "Remote Folder: $REMOTE"
    
    # Database backup
    echo "Running pg_dump..."
    if docker exec "$CONTAINER" pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$LOCAL_FILE" 2>/dev/null; then
        echo "Compressing database backup..."
        gzip -f "$LOCAL_FILE"
        
        # .env backup
        echo "Backing up .env file..."
        cp "$ENV_FILE" "$LOCAL_ENV_FILE"
        gzip -f "$LOCAL_ENV_FILE"
        
        # Upload to Google Drive
        echo "Uploading database and .env backup to Google Drive..."
        rclone copy "$COMPRESSED_FILE" "$REMOTE"
        rclone copy "$COMPRESSED_ENV_FILE" "$REMOTE"
        
        # Delete old remote files
        echo "Deleting remote backups older than 7 days..."
        rclone delete "$REMOTE" --min-age 7d
        
        echo "✓ Biplace $ENV backup completed"
    else
        echo "⚠ Failed to backup database for $ENV (container may not be running)"
        return 1
    fi
}

# ----------- MAIN EXECUTION -----------

echo "----- BACKUP STARTED -----"
echo "Date: $(date)"
echo "Backup Directory: $BACKUP_DIR"
echo "----------------------------------------"

# Clean local backup directory
echo "Cleaning backup directory: $BACKUP_DIR"
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup Vaultwarden
backup_vaultwarden

# Backup Biplace Booking environments
backup_biplace_env "staging"
backup_biplace_env "prod"

echo ""
echo "----------------------------------------"
echo "----- BACKUP FINISHED -----"
echo "All backups stored in: $BACKUP_DIR"
