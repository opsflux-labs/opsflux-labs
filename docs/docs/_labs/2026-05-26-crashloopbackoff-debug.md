---
title: "Debugging a CrashLoopBackOff in Kubernetes"
date: 2026-05-26
summary: "Diagnosed and resolved a CrashLoopBackOff caused by a misconfigured liveness probe and missing environment variable in a production-style deployment."
difficulty: intermediate
duration: 45 mins
tags: [kubernetes, debugging, liveness-probe]
github_link: https://github.com/opsflux-labs/daily-labs/tree/main/kubernetes/crashloopbackoff-debug
---

## Scenario

A ticket came in: the `api-gateway` pod in the `production` namespace keeps restarting. The app team says it was working fine yesterday. No code changes were made.

## Investigation

First, check the pod status:

```bash
kubectl get pods -n production
```

Output:
```
NAME                          READY   STATUS             RESTARTS   AGE
api-gateway-7d9f8b-xkp2q     0/1     CrashLoopBackOff   8          12m
```

Check the logs from the crashing container:

```bash
kubectl logs api-gateway-7d9f8b-xkp2q -n production --previous
```

Output:
```
Error: DATABASE_URL environment variable is not set
Process exited with code 1
```

Check the deployment spec:

```bash
kubectl describe deployment api-gateway -n production
```

The liveness probe was also hitting `/healthz` after only 5 seconds — before the app had time to start.

## Root Cause

Two issues found:

1. **Missing env var** — A recent ConfigMap update accidentally removed `DATABASE_URL`
2. **Aggressive liveness probe** — `initialDelaySeconds` was set to `5` instead of `30`

## Fix

Patch the ConfigMap to restore the missing variable:

```bash
kubectl edit configmap app-config -n production
```

Add back:
```yaml
DATABASE_URL: "postgres://db-service:5432/appdb"
```

Update the liveness probe in the deployment:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

Apply and verify:

```bash
kubectl rollout restart deployment/api-gateway -n production
kubectl get pods -n production -w
```

## Result

Pod stabilized within 60 seconds. No further restarts.

## Key Learnings

- Always check `--previous` logs on a CrashLoopBackOff — the current container may not have logs yet
- `initialDelaySeconds` should always exceed your app's startup time
- ConfigMap changes don't auto-reload — pods need a restart to pick up new values

---

> **Time taken:** 45 minutes | **Difficulty:** Intermediate
