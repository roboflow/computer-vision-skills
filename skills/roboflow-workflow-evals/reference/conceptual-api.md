---
id: resource:conceptual-api
---

# Workflow Evals conceptual API

Spec defines success. Dataset provides truth. BindingSet connects both to exactly one concrete
WorkflowSubject. Run freezes and measures that connection. Comparison is a pure read across
compatible Runs afterwards.

The evaluation flow is:

`ground truth + Workflow result -> BindingSet -> canonical values -> evaluator -> measurements -> judgment -> aggregation -> comparison`

Use `groundTruth` for persisted trusted annotations. Treat evaluator names as implementations, not
the ontology: identify the canonical value kind, then the evaluator family, then the primitive or
preset. Measurements are facts. A normalized performance score summarizes evaluator semantics.
Pass/fail judgment exists only when a check explicitly supplies a `passRule`, and it stays per
check: no aggregate or cross-check decision exists anywhere in the engine.

Outcome checks read canonical Workflow outputs and case ground truth. Runtime latency checks read
recorded runner `runtime.latencyMs` in milliseconds against one `maxLatencyMs` in the Spec; they
require no case annotation or Workflow output binding. A latency-only Spec uses `outputs: []` and
BindingSet `outputs: {}` while retaining normal input bindings. The latency score is 1 within budget
and budget/latency above it; an optional `latencyOverBudgetMs <= 0` rule yields judgment. Errors,
timeouts and invalid timing fail. Rescore can change the budget without execution when successful
cases retain valid timing; missing runtime metrics require a rerun independently of Workflow output
capture. The runner defines the timing window, so this is not normalized server-only or per-step
profiling.

Specs and Datasets declare their subject-independent `inputs` with the same `name`, `type`, and
optional `default_value` vocabulary used by Inference Workflows. `compareWorkflowEvalContracts`
compares those declared inputs plus the engine-derived ground-truth requirements before any Case is
executed. Extra Case input and ground-truth fields are allowed and ignored until declared.

## Compile, link, instantiate, execute or score, compare

The engine interprets a Spec through an explicit staged pipeline:

`parse -> compile Spec -> link BindingSet and WorkflowSubject -> instantiate Dataset -> execute or score -> compare Runs`

1. `compileWorkflowEvalSpec` turns a parsed `WorkflowEvalSpec` into an immutable, deeply frozen
   `CompiledWorkflowEvalSpec` (compiler version `workflow-evals/compiler/v1`) or structured
   diagnostics (stable `CompileDiagnosticCode` values with `$.checks[i]...` and `$.outputs[i]...`
   source locations). A Spec declares inputs, semantic outputs, and checks; it carries no Workflow
   identity, no Workflow response path, and no comparison. Ground-truth binding paths, pass rules,
   applicability, and item-match keys are validated and parsed exactly once here. The authored input
   contract participates in the Spec fingerprint.
2. `linkWorkflowEvalPlan` (or `compileWorkflowEvalPlan` for both stages in one step) links the
   compiled Spec plus one `BindingSet` to exactly one immutable `WorkflowSubject`, producing a
   `LinkedWorkflowEvalPlan`. Linking fails on a Spec output with no Workflow binding, a binding for
   an undeclared Spec output, a missing or unexpected item collection binding, an invalid Workflow
   input binding, a required Workflow input nothing binds, a bound input the Workflow does not
   declare, or an output policy that discards required capture. Linking declares the plan's
   `WorkflowCaptureContract`: the projected top-level output fields, or a full-output capture, that
   retained evidence is guaranteed to contain.
3. `instantiateWorkflowEvalWorkGraph` validates a Dataset against the linked plan and expands it
   into a `WorkflowEvalWorkGraph` DAG with stable, collision-safe node ids (`execute:*`, `score:*`,
   `aggregate`). Full mode executes every case once; retry mode schedules only failed cases plus the
   scoring and aggregation work that depends on them; rescore mode schedules no execution nodes.
   There is no comparison node: comparison never belongs to a Run work graph.
4. `executeWorkflowEvalPlan`, `retryFailedWorkflowEvalPlan`, and `scoreWorkflowEvalEvidence` operate
   over that graph with an explicit plan. The runner is called once per Run with every scheduled
   case, and each case carries the Workflow inputs the BindingSet mapped from the Dataset case.
   `retryFailedWorkflowEvalRun` executes the retry graph end to end: it re-runs only the failed
   cases, re-evaluates only their dependent score and aggregate nodes, and preserves every
   unaffected result from the prior Run verbatim. The prior Run, evidence, and retry plan must have
   the same provenance. `rescoreWorkflowEvalEvidence` decides execution provenance and capture
   compatibility before scoring and returns a structured scored-or-rerun-required outcome. It may
   reuse retained evidence for scoring-policy or output-binding changes, but a Dataset,
   Workflow-subject, or Workflow-input-binding change requires a new execution. `runWorkflowEval` is
   the single convenient entry point for an initial execute-then-score Run; it compiles and links
   exactly once and reuses that plan for both phases. Staged callers must pass an explicit plan.
5. `compareWorkflowEvalRuns` reads two completed Runs. It mutates nothing, executes nothing, and
   returns per-check deltas plus a runtime delta. Runs are comparable only when they froze the same
   effective Spec semantics and the same Dataset snapshot; otherwise the result carries structured
   `RunComparisonDiagnosticCode` diagnostics and no deltas.

The linked plan is the single authority for ground-truth requirements, Workflow response projection,
capture requirements, rescore compatibility, and evaluator and pass-rule semantics. The initial
`workflow-evals/run/v1` artifact is deep-frozen and always records the plan fingerprint, compiler
version, Spec fingerprint, BindingSet fingerprint, Workflow subject hash, capture contract, Dataset
fingerprint, and evidence id; rescore, retry, and comparison compatibility are decided against this
persisted provenance, never by scanning observed response keys.

At the execution freeze boundary, call `fingerprintWorkflowSubject` with the final Workflow
manifest. It returns the canonical manifest, the exact UTF-8 JSON bytes to persist, and their
`sha256:` identity together. `WorkflowSubject` is the engine term for saved-current,
saved-versioned, and inline candidates; the engine does not require a platform Workflow record.

The adapter-facing staged operations are public exports: `compileWorkflowEvalSpec`,
`compareWorkflowEvalContracts`, `fingerprintWorkflowSubject`, `linkWorkflowEvalPlan`,
`instantiateWorkflowEvalWorkGraph`, `executeWorkflowEvalPlan`, and `aggregateRunResults`.

One Dataset case is one Workflow invocation. Datasets use `workflow-evals/dataset/v1` and named
`inputs`. Binary media is referenced as `{ "$asset": "relative/path" }`, never embedded as base64.

The generated catalog resource is authoritative for currently supported evaluators, measurements,
aggregations, examples, value kinds, and suggested rules. Do not invent vocabulary absent from it.

Class-set checks (`labelSet@1` and its `classification@1` preset) treat a single label as a
singleton set. Per-case F1 is the performance score; `CheckAggregate.labelSet` separately reports
subset accuracy, mean case F1, micro and macro precision/recall/F1, and per-class counts pooled from
successfully scored cases, with failed cases counted.

Keypoint checks preserve the equal-case performance convention and additionally pool versioned match
evidence into `CheckAggregate.keypoints`. Dataset AP/AR and detector-selected F1@mOKS are not
averages of image metrics. A failed applicable case withholds pooled metrics and reports coverage.
Retry/rescore rebuild pooled summaries from retained case evidence; comparison exposes pooled deltas
separately, including each Run's independently eval-optimized confidence.
