# Server Entrypoint

Ce répertoire contient la configuration du reverse proxy principal qui sert de point d'entrée pour tous les services Duck Parapente.

## Architecture

Le système utilise **Caddy** comme reverse proxy pour router les requêtes entrantes vers différents services backend selon le nom de domaine. Tous les services communiquent via un réseau Docker partagé appelé `proxy`.

## Services exposés

### 1. Biplace Booking - Production
- **URL**: `bb-backend-prod.duckparapente.fr`
- **Backend**: `bb-prod-caddy:80`
- **Description**: Environnement de production de l'application Biplace Booking
- **Source**: Voir le dépôt `biplace-booking` pour l'implémentation backend

### 2. Biplace Booking - Staging
- **URL**: `bb-backend-staging.duckparapente.fr`
- **Backend**: `bb-staging-caddy:80`
- **Description**: Environnement de staging pour tester les nouvelles fonctionnalités avant la production
- **Source**: Voir le dépôt `biplace-booking` pour l'implémentation backend

### 3. Vaultwarden (Gestionnaire de mots de passe)
- **URL**: `vault.duckparapente.fr`
- **Backend**: `vaultwarden:80`
- **Description**: Gestionnaire de mots de passe auto-hébergé compatible Bitwarden
- **Port interne**: 8443 (mappé vers le port 80 du conteneur)
- **Stockage des données**: Répertoire `./data`
- **Configuration**:
  - Inscriptions désactivées (sur invitation uniquement)
  - Protégé par token admin
  - Invitations activées

## Fonctionnement

1. **Caddy Reverse Proxy** (`entrypoint_caddy`):
   - Écoute sur les ports 80 (HTTP) et 443 (HTTPS)
   - Gère automatiquement les certificats SSL/TLS via Let's Encrypt
   - Route les requêtes selon les noms de domaine définis dans `Caddyfile`
   - Transmet les en-têtes appropriés (Real IP, Forwarded-For, Protocol)
   - Journalise toutes les requêtes au format JSON vers stdout

2. **Réseau Docker** (`proxy`):
   - Réseau externe partagé entre ce point d'entrée et les services backend
   - Permet aux conteneurs de communiquer en utilisant les noms de services comme hostnames
   - Doit être créé avant de démarrer les services: `docker network create proxy`

3. **Flux des requêtes**:
   ```
   Internet → Caddy (ports 80/443)
            ↓
            └─ Routage basé sur le domaine
               ├─ bb-backend-prod.duckparapente.fr → bb-prod-caddy:80
               ├─ bb-backend-staging.duckparapente.fr → bb-staging-caddy:80
               └─ vault.duckparapente.fr → vaultwarden:80
   ```

## Backend Biplace Booking

L'application Biplace Booking est un projet séparé situé dans le dépôt `biplace-booking`. Chaque environnement (production et staging) exécute sa propre instance avec:

- **Backend**: Serveur API NestJS
- **Frontend**: Application Nuxt.js
- **Base de données**: PostgreSQL avec Prisma ORM
- **Reverse Proxy interne**: Caddy (route entre frontend et backend)

Les services backend (`bb-prod-caddy` et `bb-staging-caddy`) sont définis dans la configuration d'infrastructure du dépôt `biplace-booking` et doivent être exécutés sur le même réseau Docker `proxy`.

## Installation

1. Créer le réseau Docker partagé:
   ```bash
   docker network create proxy
   ```

2. Démarrer les services:
   ```bash
   docker-compose up -d
   ```

3. S'assurer que les services backend de `biplace-booking` sont en cours d'exécution et connectés au réseau `proxy`.

## Persistance des données

- **Vaultwarden**: Les données sont stockées dans le répertoire `./data`
  - `db.sqlite3`: Base de données principale
  - `db.sqlite3-shm`, `db.sqlite3-wal`: Fichiers write-ahead log SQLite
  - `tmp/`: Fichiers temporaires

## Logs

Voir les logs de Caddy:
```bash
docker logs -f caddy-entrypoint
```

Voir les logs de Vaultwarden:
```bash
docker logs -f vaultwarden
```

## Backups

Des sauvegardes automatiques quotidiennes sont configurées pour tous les services (Vaultwarden et bases de données Biplace Booking). Les backups sont stockés sur Google Drive avec des politiques de rétention automatiques.

Pour plus d'informations sur la configuration des backups, les procédures de restauration et la configuration de l'infrastructure, voir [`docs/infrastructure.md`](docs/infrastructure.md).

## Notes de sécurité

- Tout le trafic est automatiquement chiffré en HTTPS via le HTTPS automatique de Caddy
- Vaultwarden est configuré avec les inscriptions désactivées
- L'accès admin à Vaultwarden nécessite la variable d'environnement `ADMIN_TOKEN`
- Les invitations peuvent être envoyées depuis le panneau d'administration
- Les backups sont chiffrés en transit vers Google Drive
