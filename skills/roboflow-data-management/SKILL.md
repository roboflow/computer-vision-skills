---
name: roboflow-data-management
description: Use when uploading images, labeling, organizing datasets, creating Roboflow projects (detection/segmentation/keypoint/classification), tags, splits, versions, or RoboQL search.
---

> **For agents — source-of-truth:** This skill is authored in [`roboflow/computer-vision-skills`](https://github.com/roboflow/computer-vision-skills) and shipped with the Roboflow plugin. If your client has loaded the plugin (you'll see `roboflow:<name>` skills in your available skills list), use those local skills — they're read fresh from disk every session. The same content served as MCP resources at `roboflow://skills/<name>/...` is a fallback for clients without the plugin and may lag this repo. **Don't call `ReadMcpResourceTool` for `roboflow://skills/...` URIs when a local `roboflow:<name>` skill is available.**

# Data Management on Roboflow

## Project Types

| Type | Annotation Format | Use Case |
|------|-------------------|----------|
| Object Detection | Bounding box (polygon/mask auto-converted) | Locate objects with boxes |
| Instance Segmentation | Polygon, Mask | Pixel-level per-object boundaries |
| Semantic Segmentation | Polygon, Mask | Pixel-level class regions |
| Keypoint Detection | Keypoints (skeleton) | Pose/skeleton estimation |
| Single-Label Classification | Image-level label (no drawn annotations) | One class per image |
| Multi-Label Classification | Image-level labels | Multiple classes per image |

Project type is set at creation and **cannot be changed later**.

## Uploading Data

### Methods

| Method | Best For | Formats |
|--------|----------|---------|
| Web UI drag-and-drop | < 1,000 images | JPG, PNG, WEBP, AVIF, BMP, MOV, MP4, PDF + 40+ annotation formats |
| CLI (`roboflow import`) | > 1,000 images (images only) | Same image formats, no video |
| MCP zip upload (`image_upload`) | Agents uploading local files, up to 2 GB / 10,000 files per zip | Images plus optional annotation files (see below) |
| Cloud storage bucket mirror | Extensive or continuously-growing data already in S3 / GCS | See `roboflow://skills/roboflow-cloud-storage/SKILL` |
| Dataset Upload Workflow Block | Collecting from production Workflows | Programmatic |
| Universe fork | Starting from a public dataset | Any Universe dataset |

**Limits:** Max 20 MB per image, max 16,400 x 10,900 px. Duplicate images are skipped automatically.

### Video Upload

Videos are split into frames at a configurable rate (1 frame/60s to 60 fps). Supported formats depend on browser (MP4 H.264 most compatible).

### CLI Upload

```bash
pip install roboflow
roboflow import -w <workspace> -p <project-id> /path/to/dataset
```

### MCP Zip Upload

`image_upload` returns a signed URL. The client zips the local files, PUTs the zip to that URL, and polls `image_upload_status` until it is `completed` or `failed`.

- **Annotations are imported.** The zip can hold annotation files next to the images. They are parsed like in the web uploader: COCO JSON (`_annotations.coco.json`), YOLO TXT (with `data.yaml` or `classes.txt`), Pascal VOC XML, CreateML JSON, CSV, and more. Annotations are matched to images by file name. In classification projects, an image's parent folder name is its class.
- **Folders set splits.** A `train/`, `valid/` or `test/` folder (also `training/`, `validation/`, `val/`, `testing/`) anywhere in an image's path sets its split. Other images use the `split` argument.
- **Annotated images go straight into the Dataset.** There is no annotation job to accept, unless the workspace has annotation review turned on (then they wait in a review job). Images without annotations land in a batch (`batch_name`, default "Uploaded via API"); label them with `annotations_save` and `add_to_dataset=true`.
- **Duplicates still get their annotations.** An image already in the project is not stored again, but its annotation from the zip is saved. If it already has an annotation, that one is kept and the image is listed in `annotationErrors` as "Image was already annotated"; pass `annotation_overwrite=true` to replace it. Classification labels are always replaced.
- **A failed chunk is safe to retry.** The zip is processed in chunks. If the status is `failed` with an `uploadErrors` entry like `chunk-0`, that chunk's images may be stored without their annotations. Upload the same zip again: stored images come back as duplicates and their missing annotations are saved. "Image was already annotated" for images that made it the first time is expected.

## Tags

Tags are free-form labels on images for organization and filtering.

| Action | How |
|--------|-----|
| Add during upload | Tag selector in upload dialog or via API |
| Add to existing images | Select images -> "Images Selected" -> "Apply tags" |
| Rename/delete in bulk | Project Settings -> Tags -> "Modify Tags" |
| Filter by tag | Search with `tag:<name>` or use Assign page filter |
| Use in versions | "Filter by Tag" preprocessing step (require/exclude/allow) |

## Dataset Search (RoboQL)

Search images via the Images page search bar, or with the MCP `images_workspace_search` tool (add `project:<slug>` to stay inside one project). Combine filters with boolean logic.

The MCP `images_search` tool does not parse RoboQL. Its query is semantic text that ranks results without filtering them, so `split:valid` there changes nothing. It filters only through its own parameters (tag, class, Dataset, batch, annotation job). Use `images_workspace_search` for splits and other RoboQL filters.

### Filters

| Filter | Example | Description |
|--------|---------|-------------|
| _(free text)_ | `person on sidewalk` | Semantic search (CLIP-based) |
| `like-image:<ID>` | `like-image:abc123` | Find visually similar images |
| `filename:` | `filename:*factory*` | Filename match (`*` for partial) |
| `tag:` | `tag:factory` | Filter by tag |
| `split:` | `split:train` | Filter by split |
| `job:` | `job:<JOB_ID>` | Filter by annotation job |
| `class:` | `class:helmet` | Has annotation with class |
| `metadata:` | `metadata:key=value` | Filter by user metadata |
| `project:` | `project:my-project` | Filter by project (workspace search) |
| `dataset:` | `dataset:my-project` | Images in the project's Dataset; `project:my-project NOT dataset:my-project` finds the ones not in it yet |
| `sort:` | `sort:updated` | Sort results |
| `min-width:` / `max-width:` | `min-width:1000` | Image dimension filters |
| `min-height:` / `max-height:` | `max-height:800` | Image dimension filters |
| `min-annotations:` / `max-annotations:` | `max-annotations:1` | Annotation count filters |

### Boolean Logic

- `AND`, `OR`, `NOT`, parentheses: `class:helmet AND NOT (tag:v1 OR tag:v2)`
- Inverted filter with `-`: `-class:vest`
- Comparison operators on numeric filters: `>`, `<`, `>=`, `<=`, `=` (e.g., `class:helmet>=3`)

## Splits (Train / Valid / Test)

Images are assigned to train, valid, or test splits. Splits are rebalanced during version generation (Step 2 in version creation). Augmentations only apply to train split.

## Dataset Versions

A version is a **frozen snapshot** of the dataset at a point in time. Changes to the project after version creation do not affect existing versions.

### Version Creation Pipeline

1. **Source selection** — images from the dataset split
2. **Train/Test split** — rebalance percentages
3. **Preprocessing** — applied to all splits (train + valid + test)
4. **Augmentation** — applied only to train split
5. **Generate** — creates immutable version

### Preprocessing Options

| Step | Effect |
|------|--------|
| Auto-Orient | Strips EXIF, normalizes orientation |
| Resize | Stretch to / Fit within / Fit (black edges) / Fit (white edges) |
| Grayscale | Convert RGB to single channel |
| Auto-Adjust Contrast | Contrast Stretching / Histogram Equalization / Adaptive (CLAHE) |
| Isolate Objects | Crop each bbox into separate image (converts OD to classification) |
| Static Crop | Crop all images to fixed region |
| Tile | Split images into NxN grid (default 2x2, helps small object detection) |
| Dynamic Crop | Crop images around a specific class |
| Modify Classes | Remap/omit classes for this version only |
| Filter Null | Control percentage of unannotated images |
| Filter by Tag | Require / Exclude / Allow images by tag |
| Random Sample | Sample a percentage of images per split |

### Augmentation Options

Applied to train images only. Configurable max version size (e.g., 3x = source + 2 augmented copies).

| Augmentation | Image Level | BBox Level | Tier |
|--------------|:-----------:|:----------:|------|
| Flip | yes | yes | Basic |
| 90 deg Rotate | yes | yes | Basic |
| Crop | yes | yes | Basic |
| Rotation | yes | yes | Basic |
| Shear | yes | yes | Basic |
| Grayscale | yes | no | Basic |
| Hue | yes | no | Basic |
| Saturation | yes | no | Basic |
| Brightness | yes | yes | Basic |
| Exposure | yes | yes | Basic |
| Blur | yes | yes | Basic |
| Noise | yes | yes | Basic |
| Camera Gain | yes | yes | Basic |
| Motion Blur | yes | yes | Basic |
| Cutout | yes | no | Enhanced (paid) |
| Mosaic | yes | no | Enhanced (paid) |

## Dataset Analytics

Available at project sidebar -> "Analytics". Shows:

- Image count, annotation count, avg image size, median aspect ratio
- Missing and null annotation counts
- Class distribution across train/valid/test
- Image dimension insights (size + aspect ratio distribution)
- Annotation heatmap (click-drag to filter images by region)
- Object count histogram (click bars to see matching images)

## Classes

Managed at Project Settings -> Classes.

| Action | Description |
|--------|-------------|
| Rename | Type new name in Override column |
| Merge | Override multiple classes to same name |
| Delete | Check Delete checkbox |
| Lock | "Lock Annotation Classes" prevents new class creation |

**Warning:** Class changes at project level affect all images (irreversible). Use version-level "Modify Classes" preprocessing for non-destructive changes.

## Annotation Groups

Annotation group = the category encompassing all classes in a project. Projects sharing the same annotation group **share their class list and annotations**.

- Enable during project creation: "Share image annotations with other projects"
- Shared annotations: editing in one project affects all linked projects
- Look for chain-link icon to identify shared images/projects
- Images shared across projects count only once toward usage

**Reusing a group name shares annotations, even with a project in the Trash.** The group is just the `annotation` name given at creation. A new project created with a name that another project already uses (trashed projects included) silently joins that group: images uploaded to it that already exist in the workspace come with their annotations, and uploading them with annotations fails with "Image was already annotated". Unless the user wants shared annotations, check the `annotation` values from `projects_list` and `trash_list` before `projects_create` and pick a name no other project uses.

## Project Folders

Folders group projects for organization. SSO workspaces can restrict folder access to specific team members.

| Action | How |
|--------|-----|
| Create | "+ New Folder" from workspace view |
| Move project | Project menu -> "Move Project" |
| Delete folder | Folder menu -> "Delete" (projects move to workspace root, not deleted) |

## Export Formats

Versions can be exported as `.zip` download or `curl` command. 40+ formats supported including COCO, YOLO, Pascal VOC, TFRecord, and more. Full list at `roboflow.com/formats`.

Export via Python SDK:

```python
project.version(1).download("yolov8")
```

## MCP apps vs plain tools

Prefab MCP apps (`create_project_app`) exist when parameters are unclear, you need real UX, or a human must confirm after seeing form fields — plain chat/MCP calls should not guess project type and license alone.


## MCP Tools Available

| Tool | Purpose |
|------|---------|
| `projects_create` | Create a new project (specify type and an unused annotation group unless sharing is intended) |
| `projects_list` / `projects_get` | List or get project details |
| `images_search` | Semantic search inside one project, with tag, class, Dataset, batch and job filters (no RoboQL) |
| `images_workspace_search` | RoboQL search across the workspace, e.g. `project:my-project split:valid` |
| `image_upload` / `image_upload_status` | Prepare a zip upload of images and optional annotations, and poll its status |
| `versions_generate` | Generate a dataset version with preprocessing/augmentation |
| `versions_get` | Inspect a version |
| `versions_export` | Export a version in a given format |

## Related Pages

- `roboflow://skills/roboflow-data-management/labeling` — annotation tools, AI labeling, Label Assist, Smart Polygon, Auto Label, annotation jobs
- `roboflow://skills/roboflow-cloud-storage/SKILL` — mirror an S3/GCS bucket into the workspace (credentials, datasources, glob rules, scheduled sync)
