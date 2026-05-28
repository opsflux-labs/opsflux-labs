---
title: "Building a Docker CI Pipeline with GitHub Actions"
date: 2026-05-24
summary: "Set up a GitHub Actions workflow that builds a Docker image, runs a Trivy security scan, and pushes to Google Artifact Registry on every merge to main."
difficulty: beginner
duration: 30 mins
tags: [ci-cd, docker, github-actions, security]
github_link: https://github.com/opsflux-labs/daily-labs/tree/main/ci-cd/docker-github-actions
---

## Scenario

Automate the Docker build and push process for a microservice. Every merge to `main` should build the image, scan it for vulnerabilities, and push to Google Artifact Registry.

## Workflow File

Create `.github/workflows/docker-build.yml`:

```yaml
name: Docker Build & Push

on:
  push:
    branches: [main]

env:
  REGISTRY: asia-south1-docker.pkg.dev
  PROJECT: opsflux-prod
  REPO: opsflux-repo
  IMAGE: api-gateway

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker ${{ env.REGISTRY }}

      - name: Build Docker image
        run: |
          docker build -t $REGISTRY/$PROJECT/$REPO/$IMAGE:${{ github.sha }} .

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.PROJECT }}/${{ env.REPO }}/${{ env.IMAGE }}:${{ github.sha }}
          format: table
          exit-code: 1
          severity: CRITICAL

      - name: Push to Artifact Registry
        run: |
          docker push $REGISTRY/$PROJECT/$REPO/$IMAGE:${{ github.sha }}
          docker tag $REGISTRY/$PROJECT/$REPO/$IMAGE:${{ github.sha }} \
                     $REGISTRY/$PROJECT/$REPO/$IMAGE:latest
          docker push $REGISTRY/$PROJECT/$REPO/$IMAGE:latest
```

## Setting Up the Secret

In your GitHub repo → Settings → Secrets:

```
GCP_SA_KEY = <base64 encoded service account JSON key>
```

The service account needs `roles/artifactregistry.writer` on the registry.

## Result

Every push to `main` now:
1. Builds the image tagged with the commit SHA
2. Scans for CRITICAL vulnerabilities (fails the pipeline if found)
3. Pushes both `:<sha>` and `:latest` tags

## Key Learnings

- Always tag with the commit SHA — `:latest` alone makes rollbacks painful
- `exit-code: 1` on Trivy makes the pipeline fail on critical CVEs — security as a gate, not an afterthought
- Store GCP credentials as a GitHub secret, never in the repo

---

> **Time taken:** 30 minutes | **Difficulty:** Beginner
