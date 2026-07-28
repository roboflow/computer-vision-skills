---
name: roboflow-batch-processing
description: Use when processing a huge number of images or videos with a Roboflow Workflow WITHOUT importing them into Roboflow — staging local or cloud files with the inference-cli, starting and monitoring batch processing jobs, downloading results, and choosing between batch processing (ETL) and datasource bucket mirroring (ELT).
---

> **For agents — source-of-truth:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills) and shipped with the Roboflow plugin. If your client has loaded the plugin (you'll see `roboflow:<name>` skills in your available skills list), use those local skills — they're read fresh from disk every session. The same content served as MCP resources at `roboflow://skills/<name>/...` is a fallback for clients without the plugin and may lag this repo. **Don't call `ReadMcpResourceTool` for `roboflow://skills/...` URIs when a local `roboflow:<name>` skill is available.**

# Batch Processing

Run a Roboflow Workflow over a very large set of images or videos on
Roboflow's autoscaling compute, without importing anything into the
workspace. Files are staged into temporary Data Staging batches, a job
processes them, and results are exported back to staging for download.

## Batch processing vs datasources (ETL vs ELT)

Two pipelines exist for "I have a ton of files in a bucket/on disk". Pick by
what the user wants to end up with:

- **Batch processing (this skill, ETL):** run a model/Workflow over the
  files and get the results out. Nothing lands in the Roboflow workspace;
  staged data expires after ~7 days. Best for one-off or recurring bulk
  inference over local disks or cloud buckets.
- **Datasources / bucket mirror (ELT, see the `cloud-storage` skill):**
  import the files INTO the workspace first for labeling, curation, and
  training, then work on them inside Roboflow.

Rule of thumb: "process and give me the outputs" → batch processing;
"get these into Roboflow" → datasources (`connect_cloud_storage`).

## Prerequisites

- The workspace needs the batch-processing feature. Gated calls fail with a
  402 "Batch processing is not enabled for this workspace. Upgrade your plan
  or contact sales at https://roboflow.com/sales."
- Jobs consume credits; the workspace must have a positive balance.
- The Workflow must already exist in the workspace (`workflows_list`,
  `workflows_create`). Jobs reference it by `workflow_id`; there is no
  inline-spec option.
- API key: set `ROBOFLOW_API_KEY` in the environment (mint one with the
  `api_keys_create` MCP tool). Never have the user paste a private key into
  chat.

## Where each step runs

Staging uploads run client-side with the inference-cli, on the machine that
can reach the files (local disk) or with the user's cloud credentials
(bucket sources). The MCP server cannot read the user's filesystem or cloud
credentials. Everything after staging is server-side via MCP tools:
`batch_processing_job_start`, `_job_get`, `_job_logs`, `_job_abort`,
`_job_restart`, `batch_processing_staging_*`.

The `batch_processing_guide` MCP tool returns this recipe plus an echo of
the arguments you pass it; it never touches files or the network.

## 1. Install the CLI

```bash
pip install inference-cli
# For s3:// gs:// az:// sources:
pip install 'inference-cli[cloud-storage]'
```

Cloud credentials are picked up from the standard env chains (AWS
credentials/profile, `GOOGLE_APPLICATION_CREDENTIALS`, or
`AZURE_STORAGE_ACCOUNT_NAME` + key/SAS).

## 2. Stage a batch

Batch ids: lowercase letters, digits, `-` or `_`. Staged batches expire
after ~7 days.

```bash
# Local images (>32 images are packed into tar shards automatically)
inference rf-cloud data-staging create-batch-of-images \
  --batch-id my-batch --images-dir ./images

# Local videos (uploaded one by one via signed URLs)
inference rf-cloud data-staging create-batch-of-videos \
  --batch-id my-batch --videos-dir ./videos

# Cloud bucket (S3/GCS/Azure; glob over object paths)
inference rf-cloud data-staging create-batch-of-images \
  --batch-id my-batch --data-source cloud-storage \
  --bucket-path 's3://my-bucket/images/**/*.jpg'

# References file: JSONL lines of {"name": ..., "url": "https://..."}
inference rf-cloud data-staging create-batch-of-images \
  --batch-id my-batch --data-source references-file --references refs.jsonl
```

Sharded, cloud-storage, and references ingests are asynchronous. Wait until
the batch is fully ingested before starting a job: poll the
`batch_processing_staging_batch_get` MCP tool (file count plus per-shard
ingest statuses), or `inference rf-cloud data-staging show-batch-details -b
my-batch` / `list-ingest-details` from the CLI.

Practical limits: up to 20,000 references per ingest request (auto-chunked),
~1,000 videos per batch suggested, image formats jpg/png/webp/bmp/jp2,
video formats mp4/mov/avi/mkv/flv/wmv/m4v.

## 3. Start the job

Prefer the MCP tool:

```
batch_processing_job_start(
  batch_id="my-batch", workflow_id="my-workflow",
  content_type="images",            # or "videos"
  machine_type="gpu",               # cpu|gpu, optional
  workers_per_machine=4,            # 1/2/4/8, optional
  aggregation_format="jsonl",       # or "csv"
  save_image_outputs=True,          # persist crops/visualizations
  max_video_fps=5,                  # videos only: prediction subsampling
)
```

CLI equivalent: `inference rf-cloud batch-processing
process-images-with-workflow -b my-batch -w my-workflow -mt gpu` (or
`process-videos-with-workflow`). Same job_id + identical definition is
idempotent; a divergent definition is rejected with a 409.

## 4. Monitor

- `batch_processing_job_get(job_id)` — status, current/planned stages,
  per-stage progress, output batches; `job.isTerminal` + `job.error` are the
  end states.
- `batch_processing_job_logs(job_id)` — info/error logs for diagnosis.
- `batch_processing_job_abort(job_id)` / `batch_processing_job_restart(job_id)`
  — stop a run, or retry a failed one (optionally overriding machine type,
  workers, timeout).

## 5. Download results

Results land in Data Staging as platform-generated batches:
`<job-id>-processing` (raw per-shard outputs) and `<job-id>-export`
(packaged, downloadable archives).

- List with `batch_processing_staging_batch_files_list(batch_id="<job-id>-export")`;
  entries carry signed `downloadURL`s (~24h expiry). Archives (`.tar` /
  `.tar.gz`) must be unpacked after download.
- Listings are capped at 10,000 entries per call. Past that scale, download
  with the CLI instead (`inference rf-cloud data-staging export-batch -b
  <job-id>-export -t ./results`, resumable), or import the source data into
  the workspace with datasources (ELT) and work inside Roboflow.
- Do this within 7 days: staged inputs and results expire.
