# Troubleshooting Workflow Evals

Errors come back as one envelope:

```json
{ "error": { "code": "...", "category": "...", "retryable": false, "requestId": "...", "message": "...", "details": {} } }
```

Quote `code`, `message`, and `requestId` when you report a problem. `retryable` says whether the
same request can succeed later without changes.

## Status codes

| Status and code | Usual cause | What to do |
| --- | --- | --- |
| `400 INVALID_REQUEST` | A field fails validation. The message names it. | Fix the named field. Common cases are below. |
| `401 AUTH_REQUIRED` | No credential, or an expired one. | Reconnect the Roboflow MCP server or send a valid key. |
| `403` (`WORKSPACE_ACCESS_DENIED` or a scope error) | The credential cannot use this workspace, lacks a `workflow-evals:*` permission, or is folder-scoped. | Check `workflow_evals_capabilities` (`effectiveActions`). Use a workspace credential with the right role. |
| `404 NOT_FOUND` | Wrong id, or the resource was deleted. | List the resource type and use a current id. |
| `409 CONFLICT` | An idempotency key reused with a different payload, a Run with nothing to retry, a Dataset locked for a contract migration, or a replay after the Spec or Dataset changed. | Read `message` and `details.reason`. Use a new key only for a new request. |
| `412 PRECONDITION_FAILED` | Stale `revision`. Someone else changed the resource. | Read it again, reapply your change, and retry. |
| `422 INVALID_SPEC` | The engine rejected a Spec. | Read the diagnostics and their JSON locations. Validate with `workflow_evals_specs_validate` before saving. |
| `422 EVAL_NOT_READY` | No Cases, incomplete Cases in the selection (`details.incompleteCaseIds`), or an Eval without a compatible Spec and Dataset. | Finish or deselect incomplete Cases, or fix the Eval's `readinessDiagnostics`. |
| `428` | A REST call without `If-Match`. | Send the current numeric revision as `If-Match`. |
| `429`, `5xx` | Rate limit or a transient failure. | Back off and retry reads. Retry commands with the same idempotency key. |

## Common failures

**`inputs.image does not match the Dataset input type`.** Image inputs must be
`{"artifactId": ...}`. Upload the file or import it (`authoring.md`); URLs are not accepted.

**`groundTruth.<field> is required by the Dataset contract`.** The Case lacks a required
ground-truth field. Add it, or save the Case as `ground_truth_state="incomplete"` and finish it
later.

**`groundTruth.<field> does not match the Dataset ground-truth type`.** The value has the wrong
kind (a string where a count is declared). Drafts are type-checked too.

**`idempotencyKey was already used for a different request`.** You reused a key for a changed
payload. Generate a new key for the new request. Reusing a key with the same payload returns
the original result and creates nothing new.

**Bindings validate, but every Case's actual value is missing.** An output path reads a field
the Workflow does not return. Compare each path with the outputs from `workflows_get` and with
a Case preparation output. Current servers report this as `unknown_workflow_output` during
validation.

**The upload `PUT` fails with `403` or `412`.** The signed URL expired, or the headers differ
from `requiredHeaders`. Start a new upload; each upload URL accepts one write.

**`workflow_evals_list` shows `draft` with `readiness_stale`.** Lists do not recompute
readiness. `workflow_evals_get` does; read the Eval to see its current state.

**A Case result is huge.** `workflow_evals_results_case_get` leaves the raw Workflow output out
unless `include_raw_output=true`. Ask for it only when you need it.

**The engine version differs from `reference/manifest.json`.** Use `workflow_evals_reference_get`
for schemas, evaluators, and examples. The guides in this skill still apply.

## Known issues

Remove an entry when the server fixes it.

- **2026-10-06**: Servers before the binding fix suggest output paths named after Spec output
  ids (`$[0].pink-count`) instead of Workflow output names (`$[0].pink_count`), and accept them
  in validation. Always check suggested paths against `workflows_get`.
- **2026-10-06**: Specs and Eval Datasets cannot be deleted. Reuse them and name test resources
  with a clear prefix.

## Without the MCP server

The same operations are a REST API under
`https://api.roboflow.com/workspaces/<workspace>/workflow-evals`. Authenticate with a bearer
token or the `api_key` query parameter. Commands that create resources take an
`Idempotency-Key` header (UUID v4); updates and replacements take `If-Match` with the numeric
revision. The full contract is at `.../workflow-evals/openapi.json`, and the
`roboflow-api-reference` skill covers authentication.
