#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

REGION="${region}"
IMAGE_URI="${image_uri}"
SECRET_ARN="${secret_arn}"

# Install Docker
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install CloudWatch Agent
yum install -y amazon-cloudwatch-agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "namespace": "Podinfo/EC2",
    "append_dimensions": {
      "AutoScalingGroupName": "$$(/opt/aws/bin/ec2-metadata -t | cut -d' ' -f2)"
    },
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"] },
      "cpu": { "resources": ["*"], "measurement": ["cpu_usage_idle"] }
    }
  }
}
EOF
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Pull and run podinfo
docker run -d \
  --name podinfo \
  -p 9898:9898 \
  -e PORT=9898 \
  -e SUPER_SECRET_TOKEN_ARN="$SECRET_ARN" \
  -e AWS_REGION="$REGION" \
  "$IMAGE_URI"