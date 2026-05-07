# Data Staging — CLI Nuances

> **Tip:** Run `inference rf-cloud data-staging <command> --help` for the canonical option list. This page covers cross-cutting concepts and per-command nuances, not every flag.

Data Staging is the storage layer for [Batch Processing](SKILL.md#batch-processing). You ingest input files into staging *batches*, run jobs that produce *output batches*, and export the outputs back out.

## Batches

A batch holds either images or videos. Two flavors:

- **Input batches** — what you create with `create-batch-of-images` / `create-batch-of-videos`. Job inputs.
- **Output batches** — produced automatically by jobs (one per job stage). Often *multipart* (e.g. predictions JSONL + persisted image outputs as separate parts).

`--batch-id` must be lowercase letters with `-` / `_`. Batches expire (see `expiryDate` from `show-batch-details`).

> **Agent guidance.** For one-off demo or ad-hoc runs, invent a sensible `--batch-id` and `--batch-name` yourself (e.g. a short descriptor plus a timestamp). For real / production workloads, **ask the user** — they likely have naming conventions (project prefix, date, ticket ID) and/or need the batch findable in the web UI later.

## Data sources for input batches

Selected via `--data-source / -ds`:

| Source | Use when | Required option |
|---|---|---|
| `local-directory` (default) | Files live on the machine running the CLI | `--images-dir` / `--videos-dir` |
| `cloud-storage` | Files live in S3, GCS, or Azure | `--bucket-path` |
| `references-file` | You have signed URLs from trusted sources | `--references` |

**Cloud storage paths** — `--bucket-path` accepts S3/GCS/Azure URLs with optional glob:

```text
s3://my-bucket/run-2026-05-06/**/*.jpg
gs://my-bucket/inbox/
az://my-container/frames/
```

**References file** — JSONL (one JSON object per line). Each line needs `name` and `url`:

```jsonl
{"name": "frame_001.jpg", "url": "https://signed.example.com/..."}
{"name": "frame_002.jpg", "url": "https://signed.example.com/..."}
```

URLs **must be signed URLs from trusted domains** (e.g. presigned S3 / GCS). Public URLs from arbitrary domains are rejected at ingest. For arbitrary public URLs, download them to a local directory first and use `local-directory`.

## Webhook notifications (URL ingests only)

`--notifications-url` registers a webhook for ingest events. `--notification-category` filters categories (`ingest-status`, `files-status`); pass the flag multiple times to select more than one. Both options are **only meaningful for `references-file` and `cloud-storage` ingests** — not for local uploads. Use `--ingest-id` to label the ingest so events are correlatable.

## Multipart batches

Output batches from jobs can have multiple *parts* (e.g. predictions JSONL, persisted image outputs). Filter operations to a part with `--part-name / -pn` on `list-batch-content` and `export-batch`. `list-batch-content` without `--part-name` returns metadata across all parts.

## Commands

### `list-batches`

Workspace-wide batch list. `--pages / -p` and `--page-size` paginate.

### `create-batch-of-images` / `create-batch-of-videos`

Create an input batch. Pick the data source and matching option:

- `local-directory` (default) → `--images-dir` / `--videos-dir`
- `cloud-storage` → `--bucket-path`
- `references-file` → `--references` (JSONL of `{name, url}`)

Optional: `--batch-name` (display name), `--ingest-id` (label the ingest), `--notifications-url` (URL ingests only).

```bash
# Local
inference rf-cloud data-staging create-batch-of-images \
  -b my-batch -i ./images

# Cloud storage
inference rf-cloud data-staging create-batch-of-images \
  -b my-batch -ds cloud-storage -bp 's3://my-bucket/run/**/*.jpg'

# Signed-URL JSONL
inference rf-cloud data-staging create-batch-of-images \
  -b my-batch -ds references-file -r ./refs.jsonl
```

### `show-batch-details`

One-shot metadata: type, content type, created/expiry dates.

### `list-batch-content`

Lists per-file metadata (download URLs, names, parts). `--part-name / -pn` filters multipart batches; `--limit / -l` caps the number of entries; `--output-file / -o` writes JSONL to disk instead of printing.

### `list-ingest-details`

Per-shard status for the ingest of a batch. Use this when a `references-file` or `cloud-storage` ingest is partially failing — it surfaces which shards are stuck or errored.

### `export-batch`

Downloads files from a batch to `--target-dir / -t`. `--part-name / -pn` filters parts; `--override-existing` re-downloads files that already exist locally (default: skip).

```bash
inference rf-cloud data-staging export-batch \
  -b OUTPUT_BATCH_ID -t ./results --part-name predictions
```

## REST reference

OpenAPI spec: <https://openapi.gitbook.com/o/-MABnPmH89-NX2aB8mq4/spec/batch-processing-rest-cli.yaml>. Endpoints used by these commands:

- `POST /data-staging/v1/external/{workspace}/batches/{batch_id}/upload/image` — single-image upload (multipart form; recommended up to ~5,000 images)
- `POST /data-staging/v1/external/{workspace}/batches/{batch_id}/bulk-upload/image-files` — request a signed URL for a `.tar` upload (high-volume)
- `POST /data-staging/v1/external/{workspace}/batches/{batch_id}/upload/video` — request a signed URL to upload a video
- `POST /data-staging/v1/external/{workspace}/batches/{batch_id}/bulk-upload/image-references` — register a list of signed URLs (powers `references-file`)
- `GET  /data-staging/v1/external/{workspace}/batches/{batch_id}/count` — file count
- `GET  /data-staging/v1/external/{workspace}/batches/{batch_id}/shards` — shard statuses (paginated)
- `GET  /data-staging/v1/external/{workspace}/batches/{batch_id}/parts` — list parts of a multipart batch
- `GET  /data-staging/v1/external/{workspace}/batches/{batch_id}/list` — list download URLs (filterable by `partName`, paginated)

All endpoints accept the API key as the `api_key` query parameter.
