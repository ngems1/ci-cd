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
