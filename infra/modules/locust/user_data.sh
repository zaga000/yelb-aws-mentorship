#!/bin/bash
set -x
exec > >(tee -a /var/log/user-data.log) 2>&1

echo "=== Installing Docker ==="
sudo yum update -y
sudo yum install -y docker

echo "=== Starting Docker ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== Writing locustfile ==="
sudo mkdir -p /opt/locust
sudo chmod 777 /opt/locust
cat <<'LOCUSTEOF' | sudo tee /opt/locust/locustfile.py
from locust import HttpUser, task, constant


class YelbUser(HttpUser):
    wait_time = constant(0)

    @task(20)
    def get_votes(self):
        self.client.get("/api/getvotes")

    @task(1)
    def vote_outback(self):
        self.client.get("/api/outback")

    @task(1)
    def vote_bucadibeppo(self):
        self.client.get("/api/bucadibeppo")

    @task(1)
    def vote_chipotle(self):
        self.client.get("/api/chipotle")

    @task(1)
    def vote_ihop(self):
        self.client.get("/api/ihop")
LOCUSTEOF

sudo chmod 644 /opt/locust/locustfile.py

echo "=== Writing S3 upload helper ==="
cat <<'UPLOADEOF' | sudo tee /opt/locust/upload-results.sh
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
cd /opt/locust
FOUND=0
for f in results_*.csv; do
  [ -e "$f" ] || continue
  FOUND=1
  aws s3 cp "$f" "s3://${results_bucket}/${results_prefix}/$TIMESTAMP/$f" --region us-east-1
done
if [ "$FOUND" -eq 0 ]; then
  echo "No results_*.csv files found in /opt/locust — run a load test first."
  exit 1
fi
echo "Results uploaded to s3://${results_bucket}/${results_prefix}/$TIMESTAMP/"
UPLOADEOF
sudo chmod +x /opt/locust/upload-results.sh

echo "=== Starting Locust container ==="
sudo docker run -d --restart always \
  --name locust \
  -p 8089:8089 \
  -v /opt/locust:/mnt/locust \
  locustio/locust:latest \
  -f /mnt/locust/locustfile.py \
  --host=${alb_url} \
  --web-host=0.0.0.0 \
  --csv=/mnt/locust/results

sleep 10
echo "=== Verifying Locust container ==="
sudo docker ps -a | grep locust
sudo docker logs locust --tail 20
ss -tlnp | grep 8089 || echo "WARNING: nothing listening on 8089 yet"

echo "=== User data finished ==="