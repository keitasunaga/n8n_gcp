#\!/bin/bash
LOG_FILE="/opt/n8n-data/health-check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

cd /opt/n8n-data/docker-compose

# サービス状態チェック
if docker compose ps  < /dev/null |  grep -q "Up"; then
    echo "[${DATE}] All services are running" >> ${LOG_FILE}
else
    echo "[${DATE}] ERROR: Some services are down" >> ${LOG_FILE}
    docker compose ps >> ${LOG_FILE}
    
    # サービス再起動を試行
    docker compose restart
fi

# ディスク使用量チェック
DISK_USAGE=$(df /opt/n8n-data | awk 'NR==2 {print $5}' | sed 's/%//')
if [ ${DISK_USAGE} -gt 80 ]; then
    echo "[${DATE}] WARNING: Disk usage is ${DISK_USAGE}%" >> ${LOG_FILE}
fi
