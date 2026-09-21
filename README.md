# Enterprise Multi-Environment CI/CD Pipeline

A standard, multi-environment enterprise CI/CD pipeline built with GitHub Actions, OpenID Connect (OIDC) authentication, Docker, and AWS S3.

This repository demonstrates automated build, test, and deployment stages across three isolated environments (`dev`, `stage`, and `prod`), enforcing branch promotion rules and a mandatory human-in-the-loop approval for production releases.

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
```


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

## 🔐 How to Implement OIDC in This Project

OpenID Connect (OIDC) is the recommended way to let GitHub Actions access AWS without storing long-lived AWS credentials.

### 1) Create an OIDC provider in AWS IAM

In the AWS Console, go to IAM > Identity providers > Add provider.

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

This tells AWS to trust tokens issued by GitHub Actions.

### 2) Create an IAM role for GitHub Actions

Create a role such as `GitHubActions-CICD-Role` and add a trust policy similar to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:ngems1/ci-cd:ref:refs/heads/dev",
            "repo:ngems1/ci-cd:ref:refs/heads/stage",
            "repo:ngems1/ci-cd:ref:refs/heads/prod"
          ]
        }
      }
    }
  ]
}
```

This restricts access to the repository and allowed branches only.

### 3) Attach S3 permissions

Add a least-privilege policy for the bucket prefixes your pipeline deploys to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::<S3_BUCKET_NAME>"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::<S3_BUCKET_NAME>/dev/*",
        "arn:aws:s3:::<S3_BUCKET_NAME>/stage/*",
        "arn:aws:s3:::<S3_BUCKET_NAME>/prod/*"
      ]
    }
  ]
}
```

### 4) Configure GitHub repository secrets and variables

In GitHub:

- Settings → Secrets and variables → Actions
- Add secret:
  - `AWS_ROLE_ARN` = `arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActions-CICD-Role`
- Add variables:
  - `AWS_REGION` = `us-east-1`
  - `S3_BUCKET_NAME` = `<your-bucket-name>`

### 5) Add OIDC permissions in the workflow

Your workflow should include:

```yaml
permissions:
  id-token: write
  contents: read
```

Then use the AWS credentials action:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
```

This allows GitHub Actions to exchange the OIDC token for temporary AWS credentials.

### 6) Deploy to the correct S3 environment prefix

After authentication, upload artifacts to the environment folder:

```yaml
- name: Upload to S3
  run: |
    aws s3 sync ./dist "s3://${{ vars.S3_BUCKET_NAME }}/${{ github.ref_name }}/" --delete
```

For example:

- `dev` → `s3://bucket/dev/`
- `stage` → `s3://bucket/stage/`
- `prod` → `s3://bucket/prod/`

### 7) Protect production with GitHub Environment approvals

Create the environments in GitHub:

- `dev`
- `stage`
- `prod`

For `prod`, enable required reviewers so the deployment cannot proceed without approval.

### 8) Benefits of OIDC

Using OIDC:

- No long-lived AWS access keys in GitHub
- Better security posture and least-privilege access
- Easier rotation and auditing
- Cleaner CI/CD automation for cloud deployments

This is the recommended approach for AWS authentication in GitHub Actions.


