---
name: roboflow-plans-and-pricing
description: Use when answering questions about Roboflow plans, credit usage, or cost estimation; directs users to roboflow.com/pricing for current dollar amounts.
---

> **For agents — source-of-truth:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills) and shipped with the Roboflow plugin. If your client has loaded the plugin (you'll see `roboflow:<name>` skills in your available skills list), use those local skills — they're read fresh from disk every session. The same content served as MCP resources at `roboflow://skills/<name>/...` is a fallback for clients without the plugin and may lag this repo. **Don't call `ReadMcpResourceTool` for `roboflow://skills/...` URIs when a local `roboflow:<name>` skill is available.**

# Plans & Pricing

For current dollar pricing, always direct the user to `roboflow.com/pricing`. Never guess at prices or quote cached dollar amounts. Plan names, credit inclusions, and credit rates can change; if a user needs a buying decision or precise estimate, treat the pricing page and in-app billing pages as the source of truth.

## Plans

| Plan | Credits | Users | Key Differences |
|------|---------|-------|-----------------|
| **Public** | Included starter credits | Limited seats | All core features; data/models are public |
| **Core** | Included base credits + add-on packs | Team seats | Private data, training analytics, model eval, weight downloads |
| **Enterprise** | Custom | Custom | RBAC, priority GPU, dedicated support, SLAs, model monitoring |

Extra credits and overage terms vary by plan. Send users to `roboflow.com/pricing` for current dollar pricing and plan packaging.

## Credit Rates

The rates below are planning guidance only; verify against `roboflow.com/credits` before giving a final estimate.

### Data

| Action | 1 Credit = |
|--------|-----------|
| Storage | 5,000 images/month |
| Uploads | 10,000 images |
| Version generation | 20,000 images |
| AI Labeling (Auto Label) | 100 images |

### Training

| Action | 1 Credit = |
|--------|-----------|
| Model training (GPU) | 30 minutes |

### Inference — Serverless (Roboflow Cloud)

| Action | 1 Credit = |
|--------|-----------|
| Hosted API (v2) | 500 seconds execution |
| Video streams (CPU) | 10 hours |
| Video streams (GPU — small) | 80 minutes |
| Video streams (GPU — medium) | 60 minutes |
| Video streams (GPU — large) | 30 minutes |

### Inference — Dedicated (Roboflow Cloud)

| Action | 1 Credit = |
|--------|-----------|
| Dedicated deployment (CPU) | 4 hours |
| Dedicated deployment (GPU) | 1 hour |
| Batch processing (CPU) | 1 hour |
| Batch processing (GPU) | 15 minutes |

### Inference — Self-Hosted

| Action | 1 Credit = |
|--------|-----------|
| Images | 3,000 images |
| Video | 500 min/camera (capped at 20 credits/mo) |

### Other

| Action | 1 Credit = |
|--------|-----------|
| Vision events | 10,000 events |
| Email notifications | 100 emails |

## Cost Estimation Guidance

When helping users estimate costs:
1. Calculate usage in credits first (use the rates above)
2. Direct the user to `roboflow.com/pricing` for current credit pricing per plan
3. Recommend the right deployment option:
   - **Low volume / getting started** → Serverless (simplest, pay-per-use)
   - **High volume / continuous** → Self-hosted via inference server/inference-sdk (same API)
   - **Predictable production load** → Dedicated deployment (consistent latency, per-hour)

## Where to Check

| What | URL |
|------|-----|
| Current pricing & plans | `roboflow.com/pricing` |
| Credit rate details | `roboflow.com/credits` |
| Your plan & billing | `app.roboflow.com/{ws}/settings/plan` |
| Your credit usage | `app.roboflow.com/{ws}/settings/usage` |
