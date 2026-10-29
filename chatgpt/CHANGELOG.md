# ChatGPT plugin changelog

## 1.1.2

- Status: uploaded to the existing plugin as draft `appsub_6ae3ca5e0fc48191b614b05d8991976f` on 2026-10-29. Metadata scan: no findings. Not submitted or published; developer attestations remain unchecked.
- Listing: concrete computer vision description, discovery keywords, capability labels, and starter prompts for logo detection, video previews, and counting. Explains that exposure analytics requires application logic and validation.
- Packaging: default build preserves the MCP-only layout published in 1.1.1. Legacy bundled-skills validation remains available with `--bundle-skills`.
- Uploaded source: `6b76e9c3a6b4a161f45483b6d8a51b4e40ecd7b2`.
- Uploaded ZIP SHA-256: `b34b73948aa3bb920f1cadb467ccc371c6cef5df98433d5ae066936e49d707b5`.
- MCP binding: existing `asdk_app_6ac2713d52dc8191913b283379e39840`, still configured.
- Discovery: see `DISCOVERY.md` for separate directory, recommendation, connection, and runtime checks.

## 1.1.1

- Status: observed published in the OpenAI dashboard and public listing on 2026-10-29.
- Downloaded release: `pluginrel_480a569535f481919cf51ce1caac2f6a`.
- Downloaded ZIP SHA-256: `87c3a52451a2f86c60f99ea93660ae72c539ccda74fd2b83ba72c0d74e405291`.
- Inventory: `plugin.json`, `mcp.json`, `assets/roboflow-icon.png`. No bundled skills.
- Release notes: removed bundled skills; workflow skills are served by the existing MCP server.
- Original source commit and publication date: not recorded in this repository and not established by this audit. This entry records the downloaded artifact, not a reconstructed source commit.

## 1.1.0

- Status: draft, not built or submitted. Waits for the endpoint model selection (roboflow/roboflow-mcp#270) to be deployed to production `/openai/mcp`.
- Built from: pending (the merge commit of this version's PR).
- Package SHA-256: pending.
- Hidden tools: roboflow-mcp `4e046185` (unchanged; #261 hides nothing on `/openai/mcp`).
- Skills baseline for the next version: pending (the merge commit above). Diffed against `56c4a88`.
- Skills: adds `roboflow-model-journey`, which follows the Roboflow Agent's model rules: choose a model, try it without an endpoint, put it on a project's live endpoint with the workspace detection default and OpenAI detection availability (roboflow/roboflow-mcp#270). Carries over the changes merged since `56c4a88`: the `skill://roboflow/<name>/SKILL.md` resource addresses (#70), upload guidance aligned with the MCP tools (#71), current pricing (#69), and the `roboflow-api-reference` API key notes on rotation dates, owners and owner candidates (#65).

## 1.0.3

- Status: published on 2026-10-16, after review (submitted on 2026-10-15). Replaces an earlier hand-built 1.0.3 upload, which was deleted before it was reviewed.
- Built from: `56c4a88` (the first build from this repo).
- Package SHA-256: `8a5f762341300f6ff5f51c1af1fc83b45d54364da816356977d341c8675a3196`.
- Hidden tools: roboflow-mcp `4e046185`.
- Skills baseline for the next version: `56c4a88`.
- Listing: short description "AI for the physical world", new long description, three starter prompts, a 1024 px icon, and brand colors `#6706CE` / `#8315F9`.
- Skills: adds `draw-vision`; removes references to tools and MCP Apps that no longer exist (`universe_search_app`, `create_project_app`, `models_upload_custom_weights`, `api_keys_unprotect`) and rewrites the "For agents" banners. `workflow-from-eval` stays out of the package because it depends on tools `/openai/mcp` hides.

## 1.0.2

- Status: published, approved on 2026-10-12.
- Every Roboflow action is a separate, individually described tool. Updated the skills for building and running Workflows, uploading zipped datasets with annotations, and searching workspace images.
