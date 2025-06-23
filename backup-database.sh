#\!/bin/bash
BACKUP_DIR="/opt/n8n-data/docker-compose/backups"
DATE=$(date '+%Y%m%d_%H%M%S')
DB_NAME="n8n"
DB_USER="n8n_user"

# PostgreSQLバックアップ
cd /opt/n8n-data/docker-compose
docker compose exec -T postgres pg_dump -U ${DB_USER} ${DB_NAME} > ${BACKUP_DIR}/n8n_backup_${DATE}.sql

# 7日以上古いバックアップを削除
find ${BACKUP_DIR} -name "n8n_backup_*.sql" -mtime +7 -delete

echo "Backup completed: n8n_backup_${DATE}.sql"
