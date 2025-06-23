# n8n GCP Deployment

GCP VM上でn8n + PostgreSQLを動作させるためのDocker Compose設定

## 主要ファイル

- docker-compose/docker-compose.yml: メイン設定
- docker-compose/.env.example: 環境変数テンプレート
- backup-database.sh: DBバックアップ
- backup-config.sh: 設定バックアップ
- health-check.sh: ヘルスチェック
