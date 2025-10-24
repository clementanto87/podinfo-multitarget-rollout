#!/bin/bash
set -e

# Install Docker
yum update -y
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Login to ECR
aws ecr get-login-password --region ${region} | docker login --username AWS --password-stdin ${image_uri%%/*}

# Pull and run the container
docker pull ${image_uri}

# Get secret from Secrets Manager
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id ${secret_arn} --region ${region} --query SecretString --output text)

# Run the container
docker run -d \
  --name podinfo \
  --restart unless-stopped \
  -p 9898:9898 \
  -e SECRET_TOKEN="$SECRET_VALUE" \
  ${image_uri}

# Install CodeDeploy agent
yum install -y ruby wget
cd /home/ec2-user
wget https://aws-codedeploy-${region}.s3.${region}.amazonaws.com/latest/install
chmod +x ./install
./install auto