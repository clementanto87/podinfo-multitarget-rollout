#!/bin/bash
set -e

# Construct image URI from ECR repo and digest
IMAGE_URI="${ECR_REPO_URL}@${IMAGE_DIGEST}"
ECR_REGISTRY=$(echo "${ECR_REPO_URL}" | cut -d'/' -f1)

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
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin $ECR_REGISTRY

# Pull and run the container
docker pull $IMAGE_URI

# Get secret from Secrets Manager
SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id ${SUPER_SECRET_TOKEN_ARN} --region ${REGION} --query SecretString --output text)

# Run the container
docker run -d \
  --name podinfo \
  --restart unless-stopped \
  -p 9898:9898 \
  -e SUPER_SECRET_TOKEN_ARN="${SUPER_SECRET_TOKEN_ARN}" \
  $IMAGE_URI

# Install CodeDeploy agent
yum install -y ruby wget
cd /home/ec2-user
wget https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install
chmod +x ./install
./install auto