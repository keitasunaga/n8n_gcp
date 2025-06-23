#\!/bin/bash
BACKUP_DIR="/opt/n8n-data/docker-compose/backups"
DATE=$(date '+%Y%m%d_%H%M%S')
CONFIG_DIR="/opt/n8n-data/docker-compose"

# 設定ファイルバックアップ
tar -czf ${BACKUP_DIR}/config_backup_${DATE}.tar.gz   -C ${CONFIG_DIR}   docker-compose.yml   .env

# 7日以上古いバックアップを削除
find ${BACKUP_DIR} -name "config_backup_*.tar.gz" -mtime +7 -delete

echo "Config backup completed: config_backup_${DATE}.tar.gz"
