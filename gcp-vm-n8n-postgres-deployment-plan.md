# GCP VM n8n + PostgreSQL 構築計画書

## プロジェクト概要
- **プロジェクト名**: samuraigcp
- **構成**: n8n + PostgreSQL on Docker Compose
- **環境**: Google Cloud Platform VM
- **リージョン**: asia-northeast1（東京）

## アーキテクチャ概要
```
[インターネット] 
      ↓
[Cloudflare Network]
      ↓
[Cloudflare Tunnel (cloudflared)]
      ↓
[GCP VM Instance]
      ├── Docker Compose
      │   ├── n8n (Port: 5678)
      │   └── PostgreSQL (Port: 5432)
      ├── データ永続化 (Persistent Disk)
      └── バックアップ (Cloud Storage)
```

## 1. GCP VM構築

### 1.1 VM仕様（推奨構成オプション）

#### オプション1: 小規模構成（推奨）
```yaml
VM仕様:
  マシンタイプ: e2-medium (1 vCPU, 4GB RAM)
  ブートディスク: Ubuntu 22.04 LTS (20GB)
  追加ディスク: 30GB SSD (データ永続化用)
  リージョン: asia-northeast1-a
  ネットワーク: default VPC
  静的IP: 付与
  用途: 個人利用、小規模チーム（~5ユーザー)
  月額費用: 約¥4,500
```

#### オプション2: 最小構成
```yaml
VM仕様:
  マシンタイプ: e2-small (0.5 vCPU, 2GB RAM)
  ブートディスク: Ubuntu 22.04 LTS (20GB)
  追加ディスク: 20GB SSD (データ永続化用)
  リージョン: asia-northeast1-a
  ネットワーク: default VPC
  静的IP: 付与
  用途: 個人利用、軽量ワークフロー
  月額費用: 約¥2,800
```

#### オプション3: 超小規模構成（無料枠活用）
```yaml
VM仕様:
  マシンタイプ: e2-micro (0.25-2 vCPU, 1GB RAM)
  ブートディスク: Ubuntu 22.04 LTS (20GB)
  追加ディスク: 10GB SSD (データ永続化用)
  リージョン: us-central1, us-west1, us-east1
  ネットワーク: default VPC
  静的IP: 付与
  用途: テスト、学習用
  月額費用: 約¥1,200（無料枠適用時）
```

#### オプション4: 標準構成（元の設定）
```yaml
VM仕様:
  マシンタイプ: e2-standard-2 (2 vCPU, 8GB RAM)
  ブートディスク: Ubuntu 22.04 LTS (20GB)
  追加ディスク: 50GB SSD (データ永続化用)
  リージョン: asia-northeast1-a
  ネットワーク: default VPC
  静的IP: 付与
  用途: 中規模チーム、複雑ワークフロー
  月額費用: 約¥10,200
```

### 1.2 VM作成コマンド

#### 基本設定
```bash
# GCPプロジェクト設定（実際のプロジェクトIDに変更してください）
PROJECT_ID="samuraigcp"
ZONE="asia-northeast1-a"
VM_NAME="n8n-postgres-vm"

# プロジェクト設定
gcloud config set project ${PROJECT_ID}
```

#### オプション1: 小規模構成（推奨）
```bash
# 【重要】環境変数が正しく設定されていることを確認
echo "PROJECT_ID: $PROJECT_ID, ZONE: $ZONE, VM_NAME: $VM_NAME"

# VM作成（e2-medium: 1 vCPU, 4GB RAM）
gcloud compute instances create n8n-postgres-vm \
  --zone=asia-northeast1-a \
  --machine-type=e2-medium \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
  --metadata=enable-oslogin=true \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account=default \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --create-disk=auto-delete=yes,boot=yes,device-name=n8n-postgres-vm,image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20241119,mode=rw,size=20,type=projects/samuraigcp/zones/asia-northeast1-a/diskTypes/pd-balanced \
  --create-disk=device-name=n8n-data,mode=rw,size=30,type=projects/samuraigcp/zones/asia-northeast1-a/diskTypes/pd-ssd \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=environment=production,application=n8n,size=small \
  --reservation-affinity=any
```

#### オプション2: 最小構成
```bash
# VM作成（e2-small: 0.5 vCPU, 2GB RAM）
gcloud compute instances create ${VM_NAME} \
  --zone=${ZONE} \
  --machine-type=e2-small \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
  --metadata=enable-oslogin=true \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account=default \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --create-disk=auto-delete=yes,boot=yes,device-name=${VM_NAME},image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20241119,mode=rw,size=20,type=projects/${PROJECT_ID}/zones/${ZONE}/diskTypes/pd-balanced \
  --create-disk=device-name=n8n-data,mode=rw,size=20,type=projects/${PROJECT_ID}/zones/${ZONE}/diskTypes/pd-ssd \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=environment=production,application=n8n,size=minimal \
  --reservation-affinity=any
```

#### オプション3: 超小規模構成（無料枠）
```bash
# VM作成（e2-micro: 0.25 vCPU, 1GB RAM）
# 注意: 無料枠はus-central1, us-west1, us-east1リージョンのみ
export ZONE="us-central1-a"  # 無料枠リージョンに変更

gcloud compute instances create ${VM_NAME} \
  --zone=${ZONE} \
  --machine-type=e2-micro \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=default \
  --metadata=enable-oslogin=true \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account=default \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --create-disk=auto-delete=yes,boot=yes,device-name=${VM_NAME},image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20241119,mode=rw,size=20,type=projects/${PROJECT_ID}/zones/${ZONE}/diskTypes/pd-balanced \
  --create-disk=device-name=n8n-data,mode=rw,size=10,type=projects/${PROJECT_ID}/zones/${ZONE}/diskTypes/pd-ssd \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=environment=development,application=n8n,size=micro \
  --reservation-affinity=any
```

#### 静的IP設定（全構成共通）
```bash
# 静的IP予約（リージョンに注意）
gcloud compute addresses create n8n-static-ip --region=asia-northeast1
# 無料枠の場合: gcloud compute addresses create n8n-static-ip --region=us-central1

# 静的IPをVMに割り当て
gcloud compute instances delete-access-config n8n-postgres-vm --zone=asia-northeast1-a
STATIC_IP=$(gcloud compute addresses describe n8n-static-ip --region=asia-northeast1 --format="get(address)")
gcloud compute instances add-access-config n8n-postgres-vm \
  --zone=asia-northeast1-a \
  --access-config-name="external-nat" \
  --address=$STATIC_IP
# 無料枠の場合: --address=$(gcloud compute addresses describe n8n-static-ip --region=us-central1 --format="get(address)")
```

### 1.3 ファイアウォール設定
```bash
# Cloudflare Tunnelを使用するため、HTTP/HTTPSポートは開放不要
# SSH接続のみ許可（必要に応じて特定IPに制限）
gcloud compute firewall-rules create allow-ssh \
  --allow tcp:22 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow SSH access"

# 注意: Cloudflare Tunnelを使用するため、
# n8nは直接インターネットに公開されません
```

## 2. VM初期設定

### 2.1 VMに接続
```bash
# SSH接続
gcloud compute ssh ${VM_NAME} --zone=${ZONE}
```

### 2.2 基本ソフトウェアインストール
```bash
# パッケージ更新
sudo apt update && sudo apt upgrade -y

# 必要パッケージインストール
sudo apt install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  ufw \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release

# Docker インストール
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Dockerユーザー権限追加
sudo usermod -aG docker $USER

# Dockerサービス開始・自動起動設定
sudo systemctl start docker
sudo systemctl enable docker
```

### 2.3 データディスクマウント
```bash
# データディスク確認
lsblk

# データディスクフォーマット（初回のみ）
sudo mkfs.ext4 -F /dev/sdb

# マウントポイント作成
sudo mkdir -p /opt/n8n-data

# マウント
sudo mount /dev/sdb /opt/n8n-data

# 自動マウント設定
echo '/dev/sdb /opt/n8n-data ext4 defaults 0 0' | sudo tee -a /etc/fstab

# 権限設定
sudo chown -R $USER:$USER /opt/n8n-data
```

## 3. Docker Compose設定

### 3.1 プロジェクトディレクトリ作成
```bash
# プロジェクトディレクトリ作成
mkdir -p /opt/n8n-data/docker-compose
cd /opt/n8n-data/docker-compose

# 必要ディレクトリ作成
mkdir -p {postgres-data,n8n-data,backups}
```

### 3.2 docker-compose.yml作成

#### 標準構成・小規模構成用
```yaml
# docker-compose.yml
version: '3.8'

services:
  # PostgreSQL データベース
  postgres:
    image: postgres:16.4
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "127.0.0.1:5432:5432"  # ローカルホストのみアクセス許可
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n_user -d n8n"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - n8n-network

  # n8n ワークフロー自動化ツール
  n8n:
    image: ghcr.io/n8n-io/n8n:latest
    container_name: n8n-app
    restart: unless-stopped
    environment:
      # データベース設定
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: n8n_user
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      
      # n8n基本設定
      N8N_HOST: ${N8N_HOST}
      N8N_PORT: 5678
      N8N_PROTOCOL: http
      WEBHOOK_URL: ${WEBHOOK_URL}
      
      # セキュリティ設定
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      N8N_USER_MANAGEMENT_DISABLED: false
      
      # その他設定
      GENERIC_TIMEZONE: Asia/Tokyo
      N8N_LOG_LEVEL: info
      N8N_DIAGNOSTICS_ENABLED: false
      N8N_VERSION_NOTIFICATIONS_ENABLED: false
      N8N_TEMPLATES_ENABLED: true
      
      # タスクランナー設定
      N8N_RUNNERS_ENABLED: true
      N8N_RUNNERS_MODE: internal
    ports:
      - "127.0.0.1:5678:5678"  # ローカルホストのみアクセス許可
    volumes:
      - ./n8n-data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - n8n-network

  # 注意: Cloudflare Tunnelを使用するため、Nginxコンテナは不要

networks:
  n8n-network:
    driver: bridge

volumes:
  postgres-data:
  n8n-data:
```

#### 最小構成・超小規模構成用（メモリ最適化）
```yaml
# docker-compose-minimal.yml
version: '3.8'

services:
  # PostgreSQL データベース（軽量設定）
  postgres:
    image: postgres:16.4-alpine  # Alpineベースでメモリ使用量削減
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n_user
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
      - ./backups:/backups
    ports:
      - "127.0.0.1:5432:5432"
    # メモリ制限を設定
    deploy:
      resources:
        limits:
          memory: 256M
    # PostgreSQL設定の軽量化
    command: >
      postgres
      -c shared_buffers=32MB
      -c effective_cache_size=128MB
      -c maintenance_work_mem=16MB
      -c work_mem=2MB
      -c max_connections=20
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n_user -d n8n"]
      interval: 60s
      timeout: 10s
      retries: 3
      start_period: 90s
    networks:
      - n8n-network

  # n8n ワークフロー自動化ツール（軽量設定）
  n8n:
    image: ghcr.io/n8n-io/n8n:latest
    container_name: n8n-app
    restart: unless-stopped
    environment:
      # データベース設定
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: n8n_user
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      
      # n8n基本設定
      N8N_HOST: ${N8N_HOST}
      N8N_PORT: 5678
      N8N_PROTOCOL: http
      WEBHOOK_URL: ${WEBHOOK_URL}
      
      # セキュリティ設定
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      N8N_USER_MANAGEMENT_DISABLED: false
      
      # その他設定
      GENERIC_TIMEZONE: Asia/Tokyo
      N8N_LOG_LEVEL: warn  # ログレベルを下げてメモリ使用量削減
      N8N_DIAGNOSTICS_ENABLED: false
      N8N_VERSION_NOTIFICATIONS_ENABLED: false
      N8N_TEMPLATES_ENABLED: false  # テンプレート機能を無効化
      
      # タスクランナー設定（軽量化）
      N8N_RUNNERS_ENABLED: false  # 外部ランナーを無効化
      
      # メモリ制限のためのNode.js設定
      NODE_OPTIONS: "--max-old-space-size=512"
    ports:
      - "127.0.0.1:5678:5678"
    volumes:
      - ./n8n-data:/home/node/.n8n
    # メモリ制限を設定
    deploy:
      resources:
        limits:
          memory: 512M
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --spider -q http://localhost:5678/healthz || exit 1"]
      interval: 60s
      timeout: 15s
      retries: 3
      start_period: 120s
    networks:
      - n8n-network

networks:
  n8n-network:
    driver: bridge

volumes:
  postgres-data:
  n8n-data:
```

### 3.3 環境変数設定
```bash
# .env ファイル作成（実際のドメインに変更してください）
cd /opt/n8n-data/docker-compose
cat > .env << 'EOF'
# PostgreSQL設定
POSTGRES_PASSWORD=your_super_secure_password_here_$(openssl rand -hex 16)

# n8n設定
N8N_HOST=0.0.0.0
N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
WEBHOOK_URL=https://n8n.samurai-ar.jp

# ドメイン設定
DOMAIN=n8n.samurai-ar.jp
EOF

# 権限設定
chmod 600 .env
```

### 3.4 Cloudflared（Cloudflare Tunnel）エージェントインストール
```bash
# Cloudflaredのインストール（最新URLを使用）
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# 認証（Cloudflareアカウントに対して）
cloudflared tunnel login

# トンネル作成
cloudflared tunnel create n8n-tunnel

# 【重要】作成されたトンネルIDをメモしてください（例：3ef447e1-77e4-4afc-9889-53bcb5fbf734）

# DNS CNAMEレコード自動作成
cloudflared tunnel route dns n8n-tunnel n8n.samurai-ar.jp

# 設定ファイルディレクトリ作成
sudo mkdir -p /etc/cloudflared

# トンネル設定ファイル作成（実際のトンネルIDとクレデンシャルファイルパスに置き換えてください）
sudo tee /etc/cloudflared/config.yml << EOF
tunnel: <実際のトンネルID>
credentials-file: /home/\$USER/.cloudflared/<実際のトンネルID>.json

ingress:
  - hostname: n8n.samurai-ar.jp
    service: http://localhost:5678
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

# cloudflaredサービス化
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

**重要な変更点:**
- **DNS設定方法**: `cloudflared tunnel route dns`コマンドでCNAMEレコードを自動作成
- **Cloudflare Dashboard導線**: 現在のUIでは **Zero Trust** → **Networks** → **Tunnels** の場合があります

## 4. Cloudflare Zero Trust セキュリティ設定

### 4.1 Access Policies設定
Cloudflare Zero Trustでアクセス制御を設定：

```bash
# Cloudflare Dashboard での設定項目：
# 1. Zero Trust → Access → Applications
# 2. "Add an application" → "Self-hosted"
# 3. アプリケーション設定：
#    - Application name: n8n Workflow
#    - Session Duration: 24h
#    - Application domain: n8n.samurai-ar.jp
# 4. Policies設定：
#    - Policy name: n8n Admin Access
#    - Action: Allow
#    - Include: Emails - admin@n8n.samurai-ar.jp
```

### 4.2 セキュリティ設定の利点
- **SSL証明書自動管理**: Cloudflareが自動でSSL/TLS証明書を管理
- **DDoS保護**: Cloudflareのネットワークによる自動DDoS保護
- **Zero Trust認証**: IP制限、メール認証、MFA等の高度な認証
- **WAF**: Web Application Firewallによる攻撃防御
- **直接露出回避**: サーバーが直接インターネットに露出しない

## 5. サービス起動

### 5.1 Docker Compose起動
```bash
# プロジェクトディレクトリに移動
cd /opt/n8n-data/docker-compose

# サービス起動
docker compose up -d

# 【重要】n8nの権限問題解決
# n8nコンテナが起動後にエラーが出る場合は以下を実行
sudo chown -R 1000:1000 /opt/n8n-data/docker-compose/n8n-data
docker compose restart n8n

# サービス状態確認（両方がhealthyになるまで待機）
docker compose ps

# 30秒待機してからn8nアクセス確認
sleep 30
curl -I http://localhost:5678

# ログ確認
docker compose logs -f
```

### 5.2 OS再起動時の自動起動設定
```bash
# Docker Compose自動起動用systemdサービス作成
sudo tee /etc/systemd/system/n8n-docker-compose.service << 'EOF'
[Unit]
Description=n8n Docker Compose Service
Requires=docker.service
After=docker.service
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/n8n-data/docker-compose
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# systemd設定再読み込み
sudo systemctl daemon-reload

# サービス自動起動有効化
sudo systemctl enable n8n-docker-compose.service

# サービス起動テスト
sudo systemctl start n8n-docker-compose.service

# サービス状態確認
sudo systemctl status n8n-docker-compose.service
```

### 5.3 サービス管理コマンド
```bash
# サービス停止
docker compose down

# サービス再起動
docker compose restart

# 特定サービス再起動
docker compose restart n8n

# ログ確認
docker compose logs n8n
docker compose logs postgres
```

## 6. バックアップ設定

### 6.1 データベースバックアップスクリプト
```bash
# バックアップスクリプト作成
cat > /opt/n8n-data/backup-database.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/n8n-data/docker-compose/backups"
DATE=$(date '+%Y%m%d_%H%M%S')
DB_NAME="n8n"
DB_USER="n8n_user"

# PostgreSQLバックアップ（作業ディレクトリを指定）
cd /opt/n8n-data/docker-compose
docker compose exec -T postgres pg_dump -U ${DB_USER} ${DB_NAME} > ${BACKUP_DIR}/n8n_backup_${DATE}.sql

# 7日以上古いバックアップを削除
find ${BACKUP_DIR} -name "n8n_backup_*.sql" -mtime +7 -delete

# Cloud Storageにアップロード（オプション）
# gsutil cp ${BACKUP_DIR}/n8n_backup_${DATE}.sql gs://your-backup-bucket/

echo "Backup completed: n8n_backup_${DATE}.sql"
EOF

# 実行権限付与
chmod +x /opt/n8n-data/backup-database.sh

# cron設定（毎日3時に実行）
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/n8n-data/backup-database.sh") | crontab -
```

### 6.2 設定ファイルバックアップ
```bash
# 設定バックアップスクリプト作成
cat > /opt/n8n-data/backup-config.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/n8n-data/docker-compose/backups"
DATE=$(date '+%Y%m%d_%H%M%S')
CONFIG_DIR="/opt/n8n-data/docker-compose"

# 設定ファイルバックアップ
tar -czf ${BACKUP_DIR}/config_backup_${DATE}.tar.gz \
  -C ${CONFIG_DIR} \
  docker-compose.yml \
  .env

# 7日以上古いバックアップを削除
find ${BACKUP_DIR} -name "config_backup_*.tar.gz" -mtime +7 -delete

echo "Config backup completed: config_backup_${DATE}.tar.gz"
EOF

# 実行権限付与
chmod +x /opt/n8n-data/backup-config.sh

# cron設定（週1回実行 - 毎週日曜日2時）
(crontab -l 2>/dev/null; echo "0 2 * * 0 /opt/n8n-data/backup-config.sh") | crontab -
```

## 7. 監視・ログ設定

### 7.1 ログローテーション設定
```bash
# ログローテーション設定
sudo tee /etc/logrotate.d/docker-containers << 'EOF'
/var/lib/docker/containers/*/*-json.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF
```

### 7.2 システム監視スクリプト
```bash
# 監視スクリプト作成
cat > /opt/n8n-data/health-check.sh << 'EOF'
#!/bin/bash
LOG_FILE="/opt/n8n-data/health-check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

cd /opt/n8n-data/docker-compose

# サービス状態チェック
if docker compose ps | grep -q "Up"; then
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
EOF

# 実行権限付与
chmod +x /opt/n8n-data/health-check.sh

# cron設定（5分毎に実行）
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/n8n-data/health-check.sh") | crontab -
```

## 8. セキュリティ設定

### 8.1 UFW ファイアウォール設定
```bash
# デフォルト設定
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH許可
sudo ufw allow ssh

# UFW有効化（--forceで自動的にY応答）
sudo ufw --force enable

# 状態確認
sudo ufw status

# Cloudflare Tunnelを使用するため、HTTP/HTTPSポートは開放不要
# すべての外部接続を拒否し、Cloudflare Tunnelからのアクセスのみ許可
```

### 8.2 自動セキュリティ更新設定
```bash
# 自動更新設定
sudo apt install -y unattended-upgrades
echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
```

## 9. 初期設定完了後の確認事項

### 9.1 動作確認
```bash
# サービス状態確認
docker compose ps

# n8nアクセス確認
curl -I http://localhost:5678

# PostgreSQL接続確認
docker compose exec postgres psql -U n8n_user -d n8n -c "\l"
```

### 9.2 ドメイン設定確認
- DNSレコードが正しく設定されているか
- SSL証明書が正常に適用されているか
- HTTPSアクセスが可能か

### 9.3 バックアップ動作確認
```bash
# バックアップスクリプト実行テスト
/opt/n8n-data/backup-database.sh
/opt/n8n-data/backup-config.sh

# バックアップファイル確認
ls -la /opt/n8n-data/docker-compose/backups/
```

## 10. メンテナンス手順

### 10.1 アップデート手順
```bash
# Docker イメージ更新
cd /opt/n8n-data/docker-compose
docker compose pull
docker compose up -d

# 設定ファイルバックアップ
/opt/n8n-data/backup-config.sh
```

### 10.2 トラブルシューティング
```bash
# ログ確認
docker compose logs n8n
docker compose logs postgres

# コンテナ再起動
docker compose restart n8n

# 完全再構築
docker compose down
docker compose up -d --force-recreate
```

## 11. 費用見積もり（月額）

### 11.1 構成別コスト比較

#### オプション1: 小規模構成（推奨）
| 項目 | 仕様 | 費用（概算） |
|------|------|-------------|
| VM インスタンス | e2-medium (1 vCPU, 4GB) | ¥2,800 |
| ブートディスク | 20GB SSD | ¥400 |
| データディスク | 30GB SSD | ¥600 |
| 静的IP | 1個 | ¥800 |
| **合計** | - | **¥4,600** |

## 12. Cloudflare Zero Trust の利点

### 12.1 セキュリティ面での利点
- **直接露出回避**: サーバーが直接インターネットに露出しない
- **DDoS保護**: Cloudflareネットワークが自動でDDoS攻撃を防御
- **WAF**: Web Application Firewallで悪意のある攻撃をブロック
- **Zero Trust認証**: メール認証、MFA、IP制限等の高度な認証
- **証明書管理不要**: SSL/TLS証明書の自動管理

### 12.2 運用面での利点
- **メンテナンス簡素化**: SSL証明書更新作業が不要
- **コスト削減**: Nginxコンテナやロードバランサーが不要
- **高可用性**: Cloudflareの世界規模ネットワークによる安定性
- **パフォーマンス**: CDNによるコンテンツ配信高速化

## 13. セキュリティチェックリスト

- [ ] UFWファイアウォールが有効
- [ ] 不要なポートが閉じられている（HTTP/HTTPSポートは不要）
- [ ] Cloudflare Tunnelが正常に動作している
- [ ] Cloudflare Zero Trust Access Policiesが設定されている
- [ ] 強力なパスワードが設定されている
- [ ] 自動セキュリティ更新が有効
- [ ] バックアップが正常に動作している
- [ ] ログ監視が設定されている
- [ ] cloudflaredサービスが自動起動設定されている

---

## 14. 構成別パフォーマンス目安

### 14.1 各構成の適用可能な用途

#### 超小規模構成（e2-micro, 1GB RAM）
- **適用用途**: 学習、テスト、軽量な個人利用
- **同時実行ワークフロー**: 1-2個
- **推奨ユーザー数**: 1名
- **データベース容量**: ~1GB
- **制限事項**: 複雑なワークフローは時間がかかる場合がある

#### 最小構成（e2-small, 2GB RAM）
- **適用用途**: 個人利用、小規模自動化
- **同時実行ワークフロー**: 2-3個
- **推奨ユーザー数**: 1-2名
- **データベース容量**: ~5GB
- **制限事項**: 大量データ処理には不向き

#### 小規模構成（e2-medium, 4GB RAM）★推奨
- **適用用途**: 小規模チーム、中程度のワークフロー
- **同時実行ワークフロー**: 3-5個
- **推奨ユーザー数**: 2-5名
- **データベース容量**: ~20GB
- **制限事項**: 特になし（一般的な用途に十分）

#### 標準構成（e2-standard-2, 8GB RAM）
- **適用用途**: 中規模チーム、複雑なワークフロー
- **同時実行ワークフロー**: 5-10個
- **推奨ユーザー数**: 5-15名
- **データベース容量**: ~100GB
- **制限事項**: 特になし（高パフォーマンス）

### 14.2 選択の指針
```
個人利用かつコスト重視 → 超小規模構成
個人利用かつ安定性重視 → 最小構成
小規模チーム → 小規模構成（推奨）
中規模チーム → 標準構成
```

### 14.3 スケールアップ戦略
- **段階的アップグレード**: 小さな構成から始めて必要に応じて拡張
- **リソース監視**: CPU使用率80%超過時は上位構成への移行を検討
- **簡単な移行**: VMのマシンタイプ変更は停止→変更→再起動で完了

---

## 15. 実構築で判明した問題点と解決策

### 15.1 環境変数の問題
**問題**: bashのexport変数が正しく展開されない
**解決策**: VM作成コマンドで直接値を指定するよう修正

### 15.2 Cloudflaredインストールの問題
**問題**: 古いダウンロードURLが無効
**解決策**: GitHubの最新リリースURLに変更

### 15.3 n8n権限エラーの問題
**問題**: n8nコンテナが権限エラーで起動失敗
**解決策**: `sudo chown -R 1000:1000`でディレクトリ所有者を変更

### 15.4 Cloudflare Tunnel設定の簡素化
**問題**: 手動でのDashboard設定が複雑
**解決策**: `cloudflared tunnel route dns`でCNAME自動作成

### 15.5 cronタブ設定エラー
**問題**: `0 2 0 * 0`が無効な書式
**解決策**: `0 2 * * 0`（毎週日曜日2時）に修正

### 15.6 バックアップスクリプトの問題
**問題**: docker compose実行時に作業ディレクトリ不指定
**解決策**: スクリプト内で`cd`コマンドを追加

### 15.7 設定ファイルの問題
**問題**: 設定ファイルバックアップでnginx-config/ディレクトリ不存在
**解決策**: nginx-config/を削除（Cloudflare Tunnel使用のため不要）

## 16. 構築完了後の確認コマンド

```bash
# 全体の動作確認
cd /opt/n8n-data/docker-compose
docker compose ps
curl -I http://localhost:5678
sudo systemctl status cloudflared

# 自動起動設定確認
sudo systemctl status n8n-docker-compose.service
sudo systemctl is-enabled n8n-docker-compose.service
sudo systemctl is-enabled docker.service
sudo systemctl is-enabled cloudflared.service

# PostgreSQL確認
docker compose exec postgres psql -U n8n_user -d n8n -c "\l"
docker compose exec postgres psql -U n8n_user -d n8n -c "SELECT schemaname,tablename FROM pg_tables WHERE schemaname = 'public';"

# crontab確認
crontab -l

# ファイアウォール確認
sudo ufw status

# 静的IP確認
gcloud compute addresses describe n8n-static-ip --region=asia-northeast1 --format="get(address)"

# 再起動テスト（オプション）
# sudo reboot
# 再起動後、約2分待ってから上記の確認コマンドを実行
```

---

**注意事項:**
1. ドメイン名は実際のものに変更してください
2. パスワードは強力なものを設定してください
3. 定期的にバックアップの動作確認を行ってください
4. セキュリティ更新を定期的に適用してください
5. 本番環境では追加のセキュリティ対策を検討してください
6. **無料枠を利用する場合は、GCPの無料枠制限にご注意ください** 