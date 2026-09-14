#!/bin/bash
set -x  # логувати кожну команду в cloud-init-output.log — легше дебажити наступного разу

exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== Installing packages ==="
sudo yum update -y
sudo yum install -y docker postgresql15 bind-utils nmap-ncat

echo "=== Starting Docker ==="
sudo systemctl enable docker
sudo systemctl start docker

RDS_ENDPOINT="${rds_endpoint}"
DB_PASSWORD="${db_password}"
DB_NAME="yelbdatabase"
DB_USER="postgres"

export PGPASSWORD=$DB_PASSWORD

echo "=== Waiting for RDS to accept connections on port 5432 ==="
for i in {1..30}; do
  if nc -z -w3 "$RDS_ENDPOINT" 5432; then
    echo "RDS is reachable after $i attempt(s)"
    break
  fi
  echo "Attempt $i: RDS not reachable yet, retrying in 10s..."
  sleep 10
  if [ "$i" -eq 30 ]; then
    echo "ERROR: RDS did not become reachable after 5 minutes"
  fi
done

echo "=== Resolving RDS IP for container /etc/hosts ==="
RDS_IP=$(dig +short "$RDS_ENDPOINT" | tail -n 1)
if [ -z "$RDS_IP" ]; then
  echo "ERROR: could not resolve RDS_ENDPOINT to an IP address"
fi

echo "=== Creating database (if not exists) ==="
if psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1; then
  echo "Database $DB_NAME already exists, skipping creation"
else
  if ! psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"; then
    echo "ERROR: failed to create database $DB_NAME"
  fi
fi

echo "=== Creating table and seeding data ==="
if ! psql -h "$RDS_ENDPOINT" -U "$DB_USER" -d "$DB_NAME" -c "
CREATE TABLE IF NOT EXISTS restaurants (
    name varchar(30),
    count integer,
    PRIMARY KEY (name)
);
INSERT INTO restaurants (name, count) VALUES ('outback', 0) ON CONFLICT (name) DO NOTHING;
INSERT INTO restaurants (name, count) VALUES ('bucadibeppo', 0) ON CONFLICT (name) DO NOTHING;
INSERT INTO restaurants (name, count) VALUES ('chipotle', 0) ON CONFLICT (name) DO NOTHING;
INSERT INTO restaurants (name, count) VALUES ('ihop', 0) ON CONFLICT (name) DO NOTHING;
"; then
  echo "ERROR: failed to create/seed restaurants table"
fi

echo "=== Starting containers ==="
sudo docker run -d --restart always --name redis-server -p 6379:6379 redis:4.0.2

sudo docker run -d --restart always \
  --name yelb-appserver \
  -p 4567:4567 \
  --link redis-server:redis-server \
  --add-host=yelb-db:"$RDS_IP" \
  mreferre/yelb-appserver:0.7

sudo docker run -d --restart always \
  --name yelb-ui \
  -p 80:80 \
  -e SEARCH_DOMAIN=yelb-appserver \
  --link yelb-appserver:yelb-appserver \
  mreferre/yelb-ui:0.7

echo "=== User data script finished ==="