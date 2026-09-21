# Enterprise CI/CD Pipeline for Multi-Environment Deployment

This repository demonstrates a production-ready CI/CD workflow for a Node.js application deployed across three AWS S3 environments: `dev`, `stage`, and `prod`.

The pipeline uses:
- GitHub Actions
- OpenID Connect (OIDC) for AWS authentication
- Environment-based deployment rules
- Manual approval for production releases
- Docker-based packaging for application builds

The goal is to provide a simple, secure, and enterprise-friendly deployment model that enforces promotion between environments while avoiding long-lived AWS credentials.

---

## Overview

This project shows how to:
- Build and test an application automatically
- Upload artifacts to environment-specific prefixes in Amazon S3
- Promote code from `dev` to `stage` to `prod`
- Require human approval before production deployment
- Use AWS OIDC instead of storing static AWS access keys in GitHub

This is ideal for teams that want a practical example of secure, environment-aware deployment automation.

---

## Pipeline Flow

The workflow automatically detects the target environment based on the branch or pull request context and routes the build artifacts to the correct S3 path.

```text
Developer push to dev ──► Build ──► Upload to s3://bucket/dev/ ──► Deploy to dev

Merge into stage ─────► Build ──► Upload to s3://bucket/stage/ ─► Deploy to stage

Merge into prod ──────► Build ──► Upload to s3://bucket/prod/ ──► Manual approval ──► Deploy to prod
```

### Environment behavior
- `dev`: deploys automatically on pushes to the `dev` branch
- `stage`: deploys automatically when changes are merged into `stage`
- `prod`: requires approval before deployment begins

---

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       └── cicd.yml          # CI/CD workflow definition
├── test/                     # Automated tests
├── dockerfile                # Docker build configuration
├── package.json              # Node.js app metadata and scripts
├── package-lock.json         # Locked dependency versions
├── server.js                 # Application entry point
├── README.md                 # Project documentation
└── .gitignore
```

---

## Prerequisites

Before using this pipeline, ensure you have:

- A GitHub repository
- An AWS account
- An S3 bucket for deployment artifacts
- Permission to create IAM roles and OIDC providers in AWS
- GitHub repository access to configure:
  - Secrets
  - Variables
  - Environments
  - Required reviewers

---

## AWS Setup

### 1) Create an OIDC provider in AWS IAM

In AWS IAM, create an identity provider for GitHub Actions:

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

This allows GitHub Actions to authenticate to AWS without long-lived credentials.

---

### 2) Create an IAM role for GitHub Actions

Create a role such as:

```text
GitHubActions-CICD-Role
```

Use a trust policy similar to the following:

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

This restricts access to the repository and only allows the approved branches to assume the role.

---

### 3) Attach S3 permissions

Add a least-privilege IAM policy for the S3 deployment paths:

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

This ensures the workflow can upload artifacts to each environment-specific folder without broader bucket access.

---

## GitHub Configuration

### Secrets and variables

Go to:

`Settings → Secrets and variables → Actions`

Add the following:

#### Secret
- `AWS_ROLE_ARN` = `arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActions-CICD-Role`

#### Variables
- `AWS_REGION` = `us-east-1`
- `S3_BUCKET_NAME` = `<your-bucket-name>`

---

## GitHub Environments

Create the following GitHub environments:

- `dev`
- `stage`
- `prod`

For the `prod` environment, enable:

- Required reviewers
- Team or user approvals before deployment

This adds a human gate to production releases.

---

## Workflow Example

Your workflow should include the OIDC permission block:

```yaml
permissions:
  id-token: write
  contents: read
```

Then configure AWS credentials:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
```

After authentication, upload the build artifact to the correct environment prefix:

```yaml
- name: Upload to S3
  run: |
    aws s3 sync ./dist "s3://${{ vars.S3_BUCKET_NAME }}/${{ github.ref_name }}/" --delete
```

Examples:
- `dev` → `s3://bucket/dev/`
- `stage` → `s3://bucket/stage/`
- `prod` → `s3://bucket/prod/`

---

## Local Development

To run the application locally:

```bash
npm install
npm start
```

To run tests:

```bash
npm test
```

If the project uses Docker, you can also build locally:

```bash
docker build -t ci-cd-app .
docker run -p 3000:3000 ci-cd-app
```

---

## Deployment Strategy

This repo follows a typical enterprise promotion model:

1. Developers push code to `dev`
2. CI runs lint/test/build
3. App is deployed to the `dev` bucket
4. Changes are merged into `stage`
5. CI deploys to the `stage` bucket
6. A production pull request is reviewed
7. Production environment requires approval
8. The `prod` deployment proceeds only after approval

This ensures promotion is controlled and observable.

---

## Benefits of This Setup

Using AWS OIDC and GitHub Actions gives you several advantages:

- No long-lived AWS access keys in GitHub
- Stronger security posture
- Least-privilege access controls
- Easier auditing and rotation
- Cleaner GitHub-native deployment flow
- Controlled deployment approvals for production

---

## Security Notes

- Never commit AWS credentials to the repository
- Use GitHub repository variables and secrets only for non-sensitive configuration values and IAM role references
- Keep IAM policies narrow and environment-specific
- Enable required reviewers on production
- Restrict OIDC trust policies to the correct repository and branch names

---

## Troubleshooting

### OIDC authentication fails
Common causes:
- Trust policy does not match the repository
- Wrong branch reference in `token.actions.githubusercontent.com:sub`
- Incorrect AWS account ID in the IAM role ARN

### S3 upload fails
Check:
- IAM policy includes `s3:PutObject`
- Bucket exists
- Correct bucket name in GitHub variables
- Correct environment prefix in the deployment script

### Production deployment is blocked
Ensure:
- The `prod` environment exists
- Required reviewers are configured
- The approving user or team is assigned correctly

---

## Summary

This project is a practical example of a secure, multi-environment CI/CD pipeline built with GitHub Actions and AWS OIDC. It demonstrates how to automate testing, build artifacts, and deploy into distinct environments while enforcing approval controls for production releases.

This pattern is suitable for real enterprise workflows where security, traceability, and environment isolation matter.

---

## License

This project is intended for educational and demonstration purposes. Add a license if you plan to use it in a production or public repository.
