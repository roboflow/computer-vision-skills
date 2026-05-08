## Roboflow

This project has the Roboflow plugin installed. For any computer-vision work — datasets, annotation, training, evaluation, deployment, inference, Workflows — use the Roboflow tooling rather than rolling your own.

**Skills** loaded automatically: `api-reference`, `data-management`, `inference`, `plans-and-pricing`, `product-navigation`, `training-and-evaluation`, `universe`. Read the relevant skill before writing CV code.

**MCP server** `roboflow` (HTTP, `x-api-key: ${ROBOFLOW_API_KEY}`) provides live access to projects, images, annotations, versions, models, Workflows, Universe, evaluations.

**Prefer Workflows** over direct model inference calls. They're composable, runnable as REST endpoints, and easier to iterate on.

API key at `https://app.roboflow.com/{workspace}/settings/api`. Set `ROBOFLOW_API_KEY` in the shell that launches this agent. Never commit it.

Universe (`roboflow.com/universe`): 1M+ datasets and 50K+ models — search before training from scratch.
