# 🏗️ Podinfo Multi-Target Canary Rollout

## Overview

This repository implements a **multi-target canary deployment system** for the `podinfo` application using **AWS**, **GitHub Actions**, and **Terraform**.
It deploys the same containerized app to both:

* **AWS Lambda** (serverless)
* **EC2 + ALB** (traditional compute)
  with coordinated rollouts and rollback via **CodeDeploy**.

---

## 🚀 Architecture

```
          ┌────────────────────┐
          │ GitHub Actions CI  │
          │  - Build & Sign    │
          │  - SBOM & Push     │
          │  - Deploy via TF   │
          └────────┬───────────┘
                   │ OIDC
                   ▼
          ┌────────────────────┐
          │   AWS (Global)     │
          │ - ECR (Immutable)  │
          │ - OIDC Role        │
          │ - S3 + Dynamo TF   │
          │ - SNS + Dashboard  │
          └────────┬───────────┘
                   │
                   │
   ┌────────────────────────┐     ┌────────────────────────┐
   │ Lambda Stack (Serverless) │  │   EC2 Stack (Compute)   │
   │  • Lambda container       │  │  • ASG + LaunchTemplate │
   │  • API Gateway            │  │  • ALB Blue/Green       │
   │  • CodeDeploy Canary      │  │  • CodeDeploy BG Deploy │
   │  • CW Alarm rollback      │  │  • CW Alarm rollback    │
   └────────────────────────┘     └────────────────────────┘
```

---

## 🧱 Repository structure

```
src/                     → Go source + Dockerfile
infra/
 ├── global/             → Global AWS resources (ECR, OIDC, backend)
 ├── lambda/             → Lambda + API Gateway + CodeDeploy
 ├── ec2/                → EC2 + ALB + ASG + CodeDeploy
scripts/                 → CodeDeploy hooks + smoke tests
.github/workflows/       → CI/CD pipelines
```

---

## ⚙️ Build & CI/CD

### 1️⃣ Build pipeline: `.github/workflows/build.yml`

* Compiles Go binary and builds container image
* Generates **SBOM** using `syft`
* Signs image using **Sigstore Cosign (keyless OIDC)**
* Pushes image to **Amazon ECR**
* Outputs digest for downstream deploys

### 2️⃣ Deploy pipeline: `.github/workflows/deploy.yml`

* Triggered manually or automatically for a specific digest
* Verifies Cosign signature
* Runs `terraform apply` in both `infra/lambda` and `infra/ec2`
* Waits for CodeDeploy rollouts
* Runs smoke tests and publishes summary

### 3️⃣ Promote pipeline: `.github/workflows/promote.yml`

* Requires **manual approval** (protected “production” environment)
* Re-deploys the same signed digest to **prod**
* Verifies signature and reruns smoke tests

---

## 🐳 Local build & test

```bash
cd src
go mod tidy
go run ./cmd/podinfo
# open http://localhost:9898/healthz

docker build -t podinfo:local -f Dockerfile .
docker run -p 9898:9898 podinfo:local
```

---

## 🧩 Infrastructure bootstrap

```bash
cd infra/global
terraform init
terraform apply -auto-approve

# Capture outputs
# ecr_repo_url, github_actions_role_arn, tf_state_bucket, tf_lock_table
```

Then update your GitHub Actions workflow to use:

```yaml
role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-oidc-role
```

---

## 🌐 Deploy via GitHub Actions

1. Push to `main` to trigger the **build** job.
2. Copy the image digest from the build summary.
3. Trigger the **Deploy** workflow:

    * `image_digest`: `sha256:...`
    * `deploy_env`: `dev`
4. (Optional) Promote to production after validation.

---

## 🧠 Canary logic

| Target | Mechanism                                  | Policy                                     |
| ------ | ------------------------------------------ | ------------------------------------------ |
| Lambda | CodeDeploy `LambdaCanary10Percent5Minutes` | 10% traffic for 5 min, then 100%           |
| EC2    | CodeDeploy Blue/Green with ALB TG swap     | Rollback on CloudWatch alarm (5xx > 5/min) |

---

## 📈 Observability & Rollback

* **CloudWatch Alarms** on:

    * Lambda `Errors > 1`
    * ALB target `5xx > 5`
* Auto rollback triggered by CodeDeploy on alarm breach.
* **Correlation ID** headers in all responses for tracing.
* `/metrics` endpoint exposes Prometheus metrics.

---

## ⚡ Scalability Improvement

EC2 Auto Scaling Group includes a **target-tracking policy**:

* Scales based on `ALBRequestCountPerTarget`
* Target: 100 requests per instance
* Min = 2, Max = 6

This ensures cost-efficient scaling while maintaining reliability.

---

## 🔐 Security Highlights

* OIDC federation (no static AWS keys)
* Immutable ECR images
* Cosign signature verification before deploy
* Secrets read from AWS Secrets Manager
* Non-root Docker runtime
* Terraform backend encrypted (S3 + DynamoDB)

---

## 🧰 Useful commands

| Purpose                   | Command                                                    |
| ------------------------- | ---------------------------------------------------------- |
| Plan dev Lambda stack     | `terraform -chdir=infra/lambda plan -var="deploy_env=dev"` |
| Plan EC2 stack            | `terraform -chdir=infra/ec2 plan -var="deploy_env=dev"`    |
| Manual smoke test         | `./scripts/smoke_tests.sh <lambda_url> <alb_dns>`          |
| Validate Cosign signature | `cosign verify --keyless <ecr_repo>@<digest>`              |

---

## 🧾 Deliverables summary

| Component            | Description                      |
| -------------------- | -------------------------------- |
| `src/`               | Podinfo source + Dockerfile      |
| `infra/global`       | Shared AWS infra                 |
| `infra/lambda`       | Lambda deployment                |
| `infra/ec2`          | EC2/ALB deployment               |
| `scripts/`           | CodeDeploy hooks & smoke tests   |
| `.github/workflows/` | Build, Deploy, Promote pipelines |
| `README.md`          | Documentation (this file)        |

---

## 🧩 Next improvements (stretch goals)

* Add ACM certificate + HTTPS listener
* Attach CloudWatch dashboards to key metrics
* Add DynamoDB or RDS integration to demonstrate stateful deployment
* Integrate Slack / Teams notifications for CodeDeploy events
* Introduce chaos testing hooks for resilience validation

---

### 👤 Author

**Clement Anto**
Senior DevOps Engineer – *Take-Home Technical Challenge Solution*
GitHub Actions • AWS Terraform • CodeDeploy • OIDC • Cosign
