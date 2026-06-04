# Roboflow: Feature Lookup by Intent

> **Source-of-truth note:** This page ships with the Roboflow plugin. If your client has the plugin loaded, prefer the local skill (`roboflow:product-navigation`) over fetching `roboflow://skills/product-navigation/features-by-page` via `ReadMcpResourceTool` — the MCP resources are a fallback for non-plugin clients and may lag the source repo.

"I want to do X" -> go here / use this tool.

Base URL: `https://app.roboflow.com`

## Upload Data

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Upload images/videos | `/{ws}/{proj}/upload` | Python SDK: `project.upload(path)`, MCP: `image_upload` + `image_upload_status` |
| Import from S3/GCS/Azure | `/{ws}/{proj}/upload` -> Cloud Import tab | Python SDK with cloud URLs |
| Import from Universe | `/{ws}/{proj}/upload` -> Universe tab | MCP: `universe_search` then fork |
| Upload pre-annotated data | `/{ws}/{proj}/upload` (drag folder with annotations) | Python SDK: `project.upload(path)` auto-detects annotations |

## Annotate

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Draw bounding boxes | `/{ws}/{proj}/annotate` | -- |
| Draw polygons/masks | `/{ws}/{proj}/annotate` (select polygon/mask tool) | -- |
| Annotate keypoints | `/{ws}/{proj}/annotate` (keypoint project) | -- |
| Use AI auto-label | `/{ws}/{proj}/annotate/batch/{batchId}/autoLabel` | MCP: `annotations_save` with model predictions |
| Use Label Assist (model-assisted) | `/{ws}/{proj}/annotate` -> toggle Label Assist | -- |
| Use Smart Polygon (SAM) | `/{ws}/{proj}/annotate` -> Smart Polygon tool | -- |
| Assign labeling to team | `/{ws}/{proj}/annotate/batch/{batchId}/createJob` | MCP: `annotation_jobs_create` |
| Review annotation batches | `/{ws}/{proj}/annotate` | MCP: `annotation_batches_list`, `annotation_batches_get` |
| Check annotator productivity | `/{ws}/settings/insights` | -- |

## Manage Dataset

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Search images | `/{ws}/{proj}/images` -> search bar | MCP: `images_search` |
| Filter by class/tag/split | `/{ws}/{proj}/images` -> filter panel | -- |
| Add tags to images | `/{ws}/{proj}/images` -> select images -> Tag | -- |
| Manage classes | `/{ws}/{proj}/settings` | -- |
| Delete images | `/{ws}/{proj}/images` -> select -> Delete | -- |
| Check class balance | `/{ws}/{proj}/health` | -- |
| Merge projects | `/{ws}/merge` | -- |
| Make project public/private | `/{ws}/{proj}/sharing` | -- |

## Generate Dataset Version

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Create version with preprocessing | `/{ws}/{proj}/generate` | MCP: `versions_generate` |
| Add augmentations | `/{ws}/{proj}/generate` -> Augmentation step | MCP: `versions_generate` (augmentation params) |
| Set train/test split | `/{ws}/{proj}/generate` -> first step | MCP: `versions_generate` |
| View version details | `/{ws}/{proj}/{version}` | MCP: `versions_get` |
| Export/download version | `/{ws}/{proj}/{version}/export` | MCP: `versions_export`, Python SDK: `version.download(format)` |

## Train Models

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Train a model | `/{ws}/{proj}/train` | MCP: `models_train` |
| Choose model architecture | `/{ws}/{proj}/train` -> architecture step | MCP: `models_train` (model param) |
| Train from checkpoint | `/{ws}/{proj}/train` -> checkpoint step | MCP: `models_train` |
| Train specific version | `/{ws}/{proj}/{version}/train` | MCP: `models_train` |
| Check training status | `/{ws}/{proj}/{version}` (shows progress bar) | MCP: `models_get_training_status` |
| View training results (mAP, etc.) | `/{ws}/{proj}/{version}/train/results` | MCP: `models_get` |
| Cancel training | `/{ws}/{proj}/{version}` -> Cancel button | -- |
| Use Roboflow Instant (auto-train) | Triggers on batch approval | -- |

## Deploy & Inference

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Get API snippet for model | `/{ws}/{proj}/deploy` | -- |
| Run inference on image | `/{ws}/{proj}/deploy` -> Try tab | MCP: `models_infer` |
| Set up dedicated deployment | `/{ws}/deployments?tab=dedicated` | API |
| View edge devices | `/{ws}/deployment-manager/devices` | -- |
| Batch processing | `/{ws}/deployments?tab=batch` | -- |
| Monitor model performance | `/{ws}/vision-events` | -- |
| Upload custom model weights | `/{ws}/{proj}/deploy` -> Upload | Python SDK: `version.deploy(model_type, path)` |

## Workflows

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Create workflow | `/{ws}/workflows` -> Create | -- |
| Edit workflow (visual) | `/{ws}/workflows/{id}` | -- |
| Edit workflow JSON | `/{ws}/workflows/{id}` -> JSON tab | MCP: `workflow_specs_validate` |
| Test workflow | `/{ws}/workflows/{id}` -> Preview/Test | MCP: `workflows_run`, `workflow_specs_run` |
| Deploy workflow | `/{ws}/workflows/{id}` -> Deploy | Inference SDK, REST API |
| List available blocks | `/{ws}/workflows/{id}` -> block palette | MCP: `workflow_blocks_list` |

## Universe (Pretrained Models & Datasets)

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Search for datasets | `universe.roboflow.com` -> search | MCP: `universe_search` |
| Search for models | `universe.roboflow.com` -> search (filter: has model) | MCP: `universe_search` |
| Fork dataset to workspace | `universe.roboflow.com/{user}/{proj}` -> Fork | -- |
| Try a pretrained model | `universe.roboflow.com/{user}/{proj}/model` | MCP: `models_infer` with universe model ID |
| Download dataset | `universe.roboflow.com/{user}/{proj}` -> Download | Python SDK: `rf.universe(user, proj).version(v).download(fmt)` |

## Team & Workspace Management

| Intent | Web URL | Alternatives |
|--------|---------|-------------|
| Invite team member | `/{ws}/settings/members` -> Invite | -- |
| Change member role | `/{ws}/settings/members` -> click member | -- |
| Create project folders | `/{ws}` -> Folders section | -- |
| Set folder permissions | `/{ws}` -> Folder -> Settings | -- |
| View/change plan | `/{ws}/settings/plan` | -- |
| Check credit usage | `/{ws}/settings/usage` | -- |
| Purchase credits | `/{ws}/settings/plan` -> Buy Credits | -- |
| Update payment method | `/{ws}/settings/plan` -> Payment tab | -- |
| Get workspace API key | `/{ws}/settings/api` | -- |
| Get personal API key | `/settings/account` -> API Keys | -- |
| Configure SSO | `/{ws}/settings/plan` (Enterprise) | -- |
| View audit logs | `/{ws}/settings/audit-logs` (Enterprise) | -- |

For plans, credits, and cost estimation, see `roboflow://skills/plans-and-pricing/SKILL`.
