# ChatGPT discovery checks

Test these paths separately. A successful package build or a published directory
entry does not establish that ChatGPT can recommend an uninstalled plugin.

## Before testing

Record date/time and timezone, ChatGPT surface, plan, country, workspace type,
model, installed/connected state, listing version, and the actual tool result if
visible. Use a fresh conversation for each prompt. For pre-install discovery,
use an existing test account that has never installed Roboflow; do not uninstall
someone's working connection or count an installed-account result as a cold test.
Do not infer a search call from the assistant saying it searched.

The production listing is
https://chatgpt.com/plugins/plugin_asdk_app_6ac2713d52dc8191913b283379e39840.
It is distinct from personal or staging plugins named Roboflow.

## Test matrix

| Stage | Prompt or action | Evidence to record |
|---|---|---|
| Directory | Search the Plugins directory for `Roboflow` | Public Roboflow, Inc. result, version, install availability |
| Exact-name recommendation | `Find the Roboflow plugin and show its install card.` | Actual search result and eligible ID, whether the install card appeared |
| Task-based discovery | `I want to build a system for my company to understand how long logos are shown in baseball footage and create a solution for that and sell it how can i do it` | Whether discovery ran, queries/results, whether Roboflow was offered; keep advisory answers distinct from installation |
| Specific capability | `Find a plugin to detect and track sponsor logos in sports video.` | Search result and recommendation, not merely a web link |
| Negative control | `Make this photo look like a watercolor painting.` | No unnecessary Roboflow recommendation or tool use |
| Connection | Install from the verified public listing | Account authorization completes; tools appear in a fresh chat |
| Read-only smoke test | `Use Roboflow to find three pretrained logo detection models. Do not copy, train, deploy, or modify anything.` | Actual Universe results and links, or an accurate empty result |
| Skill delivery | Ask the connected plugin to list skills and read the relevant model journey/inference skill | Actual live skill text and supported tool names |

Run discovery prompts at least three times in fresh conversations and retain
individual results, not just a success percentage. No recommendation is guaranteed
for a general advisory question. Exact-name retrieval failure is a different
problem from the model not choosing to search.

## Diagnose by the first failing stage

- Directory missing: investigate publication, country/plan/workspace eligibility,
  and indexing. Retain the direct listing URL.
- Directory present, exact-name recommendation absent: inspect the recommendation
  service result, account/install filters and catalog identity mapping. This may
  need OpenAI investigation. Changing MCP tools or OAuth does not establish a fix.
- Exact-name works, task-based discovery weak: improve truthful listing and tool
  descriptions, capability labels and starter prompts; rerun the same prompts.
- Connection fails: inspect OAuth and MCP transport separately.
- Connected tools fail: inspect the published tool definition and runtime result.

When a search returns no eligible plugin, report that limitation honestly and
provide the verified listing link. Never invent a plugin ID or claim an install
card was shown. Never promise a finished sponsorship valuation system from a
logo detector: exposure timing, camera cuts, duplicate detections and validation
need application logic.

## Release gate

Run the package tests and build, then inspect the ZIP. The default release must
keep the MCP-only layout and the `/openai/mcp` endpoint. Upload to the existing
plugin and verify the imported metadata, configured app binding and review state.
Metadata changes require OpenAI review and publication. Capture post-publication
discovery results before marking an in-chat recommendation incident resolved.
