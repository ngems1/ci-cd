# Enterprise Multi-Environment CI/CD Pipeline

A standard, multi-environment enterprise CI/CD pipeline built with GitHub Actions, OpenID Connect (OIDC) authentication, Docker, and AWS S3.

This repository demonstrates automated build, test, and deployment stages across three isolated environments (`dev`, `stage`, and `prod`), enforcing branch promotion rules and a mandatory human-in-the-loop approval gate for production releases.

---

## 🚀 Architecture & Pipeline Flow

The workflow automatically detects the target deployment environment based on branch triggers or pull request events and routes artifacts directly into dedicated environment prefixes in Amazon S3:

```text
  [ Developer Push ]                 [ Pull Request ]                   [ Pull Request ]
          │                                  │                                  │
    push to `dev`                   merge into `stage`                 merge into `prod`
          │                                  │                                  │
          ▼                                  ▼                                  ▼
 ┌─────────────────┐                ┌─────────────────┐                ┌─────────────────┐
 │   Detect Env    │                │   Detect Env    │                │   Detect Env    │
 │ (Target: `dev`) │                │(Target: `stage`)│                │ (Target: `prod`)│
 └────────┬────────┘                └────────┬────────┘                └────────┬────────┘
          │                                  │                                  │
          ▼                                  ▼                                  ▼
 ┌─────────────────┐                ┌─────────────────┐                ┌─────────────────┐
 │ Build & Upload  │                │ Build & Upload  │                │ Build & Upload  │
 │  to s3://.../dev│                │to s3://.../stage│                │to s3://.../prod │
 └────────┬────────┘                └────────┬────────┘                └────────┬────────┘
          │                                  │                                  │
          ▼                                  ▼                                  ▼
 ┌─────────────────┐                ┌─────────────────┐                ┌─────────────────┐
 │   Run Tests     │                │   Run Tests     │                │   Run Tests     │
 └────────┬────────┘                └────────┬────────┘                └────────┬────────┘
          │                                  │                                  │
          ▼                                  ▼                                  ▼
 ┌─────────────────┐                ┌─────────────────┐                ┌─────────────────┐
 │ Deploy (`dev`)  │                │ Deploy (`stage`)│                │ Manual Approval │
 └─────────────────┘                └─────────────────┘                └────────┬────────┘
                                                                                │ (Approved)
                                                                                ▼
                                                                       ┌─────────────────┐
                                                                       │ Deploy (`prod`) │
                                                                       └─────────────────┘



🛠️ Repository Structure:
.
├── .github/
│   └── workflows/
│       └── cicd.yml     # 4-Stage GitHub Actions CI/CD pipeline
├── test/                # Unit/Integration test suites
├── dockerfile           # Production multi-stage Docker build file
├── package.json         # Node.js dependencies and scripts
├── package-lock.json    # Dependency lock file
└── server.js            # Node.js application entry point


🔐 Prerequisites & Setup
1. AWS Infrastructure & OIDC Setup
AWS S3 Bucket: Create an S3 bucket 

IAM Role: Create an IAM Role configured with OpenID Connect (OIDC) trust policy allowing
   GitHub Actions (sts:AssumeRoleWithWebIdentity) to access the bucket without long-lived credentials.


2. GitHub Configuration
Navigate to Settings > Secrets and variables > Actions and configure:
Secrets:
   * AWS_ROLE_ARN: The IAM Role ARN configured for OIDC
Variables:
   * AWS_REGION: AWS Region (e.g., us-east-1).
   * S3_BUCKET_NAME: Target S3 bucket name.


Navigate to Settings > Environments and configure:
dev
stage
prod ==> Enable Required reviewers and assign authorized team members for manual deployment approvals.




