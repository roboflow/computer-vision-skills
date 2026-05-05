# Roboflow Computer Vision Skills

This repo provides Codex skills covering Roboflow APIs, inference, data management, training, and Roboflow Universe.

## Available skills

| Skill | When to use |
|-------|-------------|
| `roboflow-api-reference` | Raw REST or Inference API calls, SDK selection, API auth |
| `roboflow-data-management` | Uploading images, labeling, dataset versions, RoboQL search |
| `roboflow-inference` | Running model inference, Workflows, deployment options |
| `roboflow-plans-and-pricing` | Credit usage, cost estimation, plan comparison |
| `roboflow-product-navigation` | Finding features in app.roboflow.com by intent |
| `roboflow-setup` | Configuring Roboflow API key for this project |
| `roboflow-training-and-evaluation` | Training models, architecture selection, improving accuracy |
| `roboflow-universe` | Searching public datasets and pre-trained models |

## MCP tools

When the Roboflow MCP server is connected, prefer its tools over raw HTTP:

- `models_infer`, `workflow_specs_run`, `workflows_run` — inference
- `projects_create`, `images_search`, `versions_generate` — data management
- `models_train`, `models_get_training_status`, `models_get` — training
- `universe_search` — Universe dataset/model search

## Auth

Set `ROBOFLOW_API_KEY` in your environment before starting Codex:

```bash
export ROBOFLOW_API_KEY=your_key_here
# or: use the roboflow-setup skill to write it to .env
```

Get your key at `https://app.roboflow.com/{workspace}/settings/api`.
