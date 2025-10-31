#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# --- 1. Install Dependencies (Docker & AWS CLI) ---
echo "Installing Docker and AWS CLI..."
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo yum install -y aws-cli
sudo service docker start
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# --- 2. Install AWS CodeDeploy Agent ---
echo "Installing CodeDeploy Agent..."
# Template variable substitution: ${REGION}
INSTALLER_URL="https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
sudo wget $INSTALLER_URL
sudo chmod +x ./install
sudo ./install auto

# --- 3. Configure Environment File for CodeDeploy/Application ---
echo "Configuring application environment file..."
ENV_FILE="/etc/profile.d/app-env.sh"
sudo mkdir -p /etc/profile.d/
# CRITICAL FIX 1: Use <<'EOF' to prevent shell variable expansion by Terraform
cat <<'EOF' | sudo tee $ENV_FILE
# Template variables are substituted here
export AWS_REGION="${REGION}"
export ECR_REPO_URL="${ECR_REPO_URL}"
export IMAGE_DIGEST="${IMAGE_DIGEST}"
export SUPER_SECRET_TOKEN_ARN="${SUPER_SECRET_TOKEN_ARN}"
EOF
sudo chmod +x $ENV_FILE

# --- 4. Configure and Start CloudWatch Agent ---
echo "Configuring CloudWatch Agent..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
# Template variable substitution: ${REGION}
ASG_NAME=$(aws autoscaling describe-auto-scaling-instances --instance-ids $INSTANCE_ID --region ${REGION} --query 'AutoScalingInstances[0].AutoScalingGroupName' --output text)

sudo yum install -y amazon-cloudwatch-agent

# CloudWatch Config File Creation
# CRITICAL FIX 2: Use <<'EOF' to prevent shell variable expansion by Terraform
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "namespace": "Podinfo/EC2",
    "append_dimensions": {
      "AutoScalingGroupName": "$ASG_NAME"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "cpu": {
        "resources": ["*"],
        "measurement": ["cpu_usage_idle"]
      },
      "disk": {
        "resources": ["/"],
        "measurement": ["disk_used_percent"]
      }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s