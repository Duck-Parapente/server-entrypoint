# Server Infrastructure Documentation

## Pré-requis

Pour gérer le serveur Duck Parapente, il te faut:

- **Accès SSH au serveur**: Clé PEM pour se connecter
- **Docker** avec le plugin compose installé sur le serveur
- **rclone** configuré avec un remote "gdrive" pour les backups ([cf. doc](https://rclone.org/drive/#making-your-own-client-id))
- **Réseau Docker proxy**: `docker network create proxy` (pour une installation from scratch)

## Accès au serveur

Configuration SSH dans `~/.ssh/config`:

```
Host duck-tower
Hostname X.X.X.X  # Remplace par l'IP publique du serveur
User root
PreferredAuthentications publickey
IdentityFile ~/.ssh/duck-tower.pem
```

Se connecter:
```bash
ssh duck-tower
```

## Architecture des répertoires sur le serveur

- `/srv/server-entrypoint/`: Services d'infrastructure (reverse proxy, Vaultwarden)
- `/srv/staging-biplace/`: Environnement de staging Biplace Booking
- `/srv/prod-biplace/`: Environnement de production Biplace Booking

## Services gérés

### 1. Server Entrypoint (ce repo)
- **Caddy**: Reverse proxy principal (ports 80/443)
- **Vaultwarden**: Gestionnaire de mots de passe
- **Localisation**: `/srv/server-entrypoint/`

### 2. Biplace Booking
- **Staging**: `/srv/staging-biplace/`
- **Production**: `/srv/prod-biplace/`
- Chaque environnement contient: backend NestJS, frontend Nuxt, base PostgreSQL, Caddy interne

## Crons configurés

### Backup automatique

Tous les jours à 3h du matin, backup complet de tous les services:

```bash
0 3 * * * /srv/server-entrypoint/scripts/backup.sh >> /var/log/backup.log 2>&1
```

Le script backup:
- **Vaultwarden**:
  - Exécute la commande interne `/vaultwarden backup` dans le conteneur
  - Exporte uniquement le dernier fichier de backup SQLite créé (`db_YYYYMMDD_HHMMSS.sqlite3`)
  - Compresse et conserve 30 jours sur Google Drive
- **Biplace Booking (staging & prod)**:
  - Dump PostgreSQL compressé
  - Fichier `.env` compressé
  - Conservés 7 jours sur Google Drive

Pour plus de détails, voir [scripts/backup.sh](../scripts/backup.sh).

### Restauration des backups

#### Vaultwarden

1. Télécharger le backup depuis Google Drive:
   ```bash
   rclone copy gdrive:backup_vaultwarden/db_YYYYMMDD_HHMMSS.sqlite3.gz /tmp/
   ```

2. Décompresser:
   ```bash
   gunzip /tmp/db_YYYYMMDD_HHMMSS.sqlite3.gz
   ```

3. Arrêter Vaultwarden:
   ```bash
   cd /srv/server-entrypoint
   docker compose stop vaultwarden
   ```

4. Remplacer la base de données:
   ```bash
   cp /tmp/db_YYYYMMDD_HHMMSS.sqlite3 /srv/server-entrypoint/data/db.sqlite3
   ```

5. Redémarrer Vaultwarden:
   ```bash
   docker compose start vaultwarden
   ```

#### Biplace Booking (staging ou prod)

1. Télécharger les backups depuis Google Drive:
   ```bash
   # Remplacer ENV par "staging" ou "prod"
   rclone copy gdrive:backup_biplace_ENV/ENV_dump_YYYYMMDD_HHMMSS.sql.gz /tmp/
   rclone copy gdrive:backup_biplace_ENV/ENV_env_YYYYMMDD_HHMMSS.env.gz /tmp/
   ```

2. Restaurer la base de données avec le script:
   ```bash
   cd /srv/ENV-biplace/infra/scripts
   ./load-dump.sh /tmp/ENV_dump_YYYYMMDD_HHMMSS.sql.gz
   ```

3. (Optionnel) Restaurer le fichier `.env` si nécessaire:
   ```bash
   gunzip /tmp/ENV_env_YYYYMMDD_HHMMSS.env.gz
   cp /tmp/ENV_env_YYYYMMDD_HHMMSS.env /srv/ENV-biplace/infra/.env
   docker compose -f infra/docker-compose.yml restart
   ```

## Déploiement

### Server Entrypoint

1. Se connecter au serveur: `ssh duck-tower`
2. Aller dans le dossier: `cd /srv/server-entrypoint`
3. Mettre à jour le code: `git pull`
4. Redémarrer les services: `docker-compose up -d`
