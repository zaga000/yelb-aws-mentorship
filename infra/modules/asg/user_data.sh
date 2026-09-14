#!/bin/bash
set -x  

exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== Installing packages ==="
sudo yum update -y
sudo yum install -y docker postgresql15 bind-utils nmap-ncat amazon-cloudwatch-agent

echo "=== Starting Docker ==="
sudo systemctl enable docker
sudo systemctl start docker

RDS_ENDPOINT="${rds_endpoint}"
DB_PASSWORD="${db_password}"
DB_NAME="yelbdatabase"
DB_USER="postgres"
ENV_NAME="${env}"

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

echo "=== Configuring CloudWatch Agent (system metrics: memory, disk) ==="
cat <<'EOF' | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/config.json
{
  "metrics": {
    "namespace": "Yelb/EC2",
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["/"]
      }
    }
  }
}
EOF

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

echo "=== Configuring ADOT Collector ==="
sudo mkdir -p /opt/adot
cat <<'EOF' | sudo tee /opt/adot/otel-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  awsxray:
    region: us-east-1

service:
  pipelines:
    traces:
      receivers: [otlp]
      exporters: [awsxray]
EOF

echo "=== Starting ADOT Collector ==="
sudo docker run -d --restart always \
  --name adot-collector \
  -p 4317:4317 \
  -p 4318:4318 \
  -v /opt/adot/otel-config.yaml:/etc/otel-config.yaml \
  --log-driver=awslogs \
  --log-opt awslogs-region=us-east-1 \
  --log-opt awslogs-group="/yelb/$ENV_NAME/adot-collector" \
  --log-opt awslogs-create-group=true \
  --log-opt awslogs-stream="$(hostname)" \
  public.ecr.aws/aws-observability/aws-otel-collector:latest \
  --config=/etc/otel-config.yaml

echo "=== Starting containers ==="
sudo docker run -d --restart always \
--name redis-server \
-p 6379:6379 \
--log-driver=awslogs \
--log-opt awslogs-region=us-east-1 \
--log-opt awslogs-group="/yelb/$ENV_NAME/redis-server" \
--log-opt awslogs-create-group=true \
--log-opt awslogs-stream="$(hostname)" \
redis:4.0.2

sudo docker run -d --restart always \
--name yelb-appserver \
-p 4567:4567 \
--link redis-server:redis-server \
--add-host=yelb-db:"$RDS_IP" \
--log-driver=awslogs \
--log-opt awslogs-region=us-east-1 \
--log-opt awslogs-group="/yelb/$ENV_NAME/yelb-appserver" \
--log-opt awslogs-create-group=true \
--log-opt awslogs-stream="$(hostname)" \
mreferre/yelb-appserver:0.7

sudo docker run -d --restart always \
--name yelb-ui \
-p 80:80 \
-e SEARCH_DOMAIN=yelb-appserver \
--link yelb-appserver:yelb-appserver \
--log-driver=awslogs \
--log-opt awslogs-region=us-east-1 \
--log-opt awslogs-group="/yelb/$ENV_NAME/yelb-ui" \
--log-opt awslogs-create-group=true \
--log-opt awslogs-stream="$(hostname)" \
mreferre/yelb-ui:0.7

echo "=== User data script finished ==="