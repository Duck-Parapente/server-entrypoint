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
- **Vaultwarden**: Archive complète du dossier `data` (conservée 30 jours sur Google Drive)
- **Biplace Booking (staging & prod)**:
  - Dump PostgreSQL compressé
  - Fichier `.env` compressé
  - Conservés 7 jours sur Google Drive

Pour plus de détails, voir [scripts/backup.sh](../scripts/backup.sh).

## Déploiement

### Server Entrypoint

1. Se connecter au serveur: `ssh duck-tower`
2. Aller dans le dossier: `cd /srv/server-entrypoint`
3. Mettre à jour le code: `git pull`
4. Redémarrer les services: `docker-compose up -d`
