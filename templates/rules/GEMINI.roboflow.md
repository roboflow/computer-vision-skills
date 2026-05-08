## Roboflow

The Roboflow MCP server is configured for this project. For computer-vision tasks — datasets, annotation, training, evaluation, deployment, inference, Workflows — use Roboflow tools rather than ad-hoc approaches.

**MCP** `roboflow` (HTTP, `x-api-key: ${ROBOFLOW_API_KEY}`): live access to projects, images, annotations, versions, models, Workflows, Universe search, evaluations.

**Workflows** are the recommended way to run inference. They compose blocks (detection, classification, OCR, foundation models) and ship as REST endpoints.

API keys live at `https://app.roboflow.com/{workspace}/settings/api`. Set `ROBOFLOW_API_KEY` in the environment that launches this agent.

Universe: `roboflow.com/universe` — 1M+ public datasets, 50K+ models. Search before training new models.
