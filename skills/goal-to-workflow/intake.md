# Intake: from a plain-words job to a scorecard

The user should not have to think in evaluators. You infer the scoring from three things: the
job, what they care about, and the media. Ask only what you cannot infer.

## The questions

Ask one at a time. Skip any the user already answered.

1. **What should the Workflow tell you about each image?** Push for concrete answers with
   names: "which stage of assembly (one of four)", "how many pallets", "is the label
   present", "where are the cracks". One answer per line. Each becomes one output. For an
   answer that depends on another ("who has the ball" depends on the scene), ask whether it
   is answered on every image or only on some; the rule goes on the Goal Card.
2. **Which mistakes are expensive?** This gives the must-never rules and the priority order.
   Examples: "it must never say done when it isn't", "missing a defect is worse than a false
   alarm", "the count must be exact". If the user says "all of it matters", pick the order
   yourself from the job and show it. If speed is mentioned anywhere, ask for the budget per
   image ("under 2 s?"); without one, latency is measured and reported, not gated.
3. **Where do the examples come from?** A video, a folder, a Roboflow project, URLs, or a
   camera they can sample. Also: is there anything already labeled, and is there a second
   source (another video, shift, site) that can be kept for validation.

Settle two small things in the same breath, without a separate question when the answer is
obvious: the **language** of answer values, names and the report (names freeze after Phase 2),
and whether a **Workflow already exists** (it joins the portfolio as pre-existing).

## Look before you write

Before the Goal Card, open the first example, the last one and two or three from the middle
(the Read tool renders images; for video, extract those frames). You are looking for examples
that fit none of the proposed answer values: an opening shot without the scoreboard, an end
card, an empty bench, a black frame. Each one becomes either a new value ("graphic") or a
"not scored here" rule (the answer is absent and the check is skipped, see "Answers that do
not apply everywhere"). Finding these during the review costs a rule change and a relabel.

## Temporal jobs are answered per frame

"When did each panel finish" or "how long does step 3 take" are questions about time. The
Workflow answers one frame at a time; the temporal answer is derived from the per-frame
answers afterwards (first frame where `done` is true, run lengths of a label). Say this on
the Goal Card so the user knows what is being scored: the per-frame answer, not the event.
When the user cares about the event, the must-never rule usually concerns the per-frame
answer that triggers it ("never say done before it is done").

## The Goal Card

Write it in the user's chosen language. Template:

```
Job: <one sentence>
Scored as: <per image | per frame of video, answers derived into events afterwards>

Answers per image:
  - <name>: <type> (<allowed values or unit>; <when it applies, if not always>)
  - <name>: <type>

Must never:
  - <rule in words>   e.g. say "done" when the assembly is not finished

Better means, in order:
  1. <criterion>   e.g. fewer wrong phases
  2. <criterion>
  3. <tie-breaker>  e.g. simpler Workflow, then faster (budget <N> s per image, or measured only)

Examples: <source>, about <N> images, <labeled? yes/no>; new examples for validation: <source or none>
```

## Answer types to evaluators

Keep the mapping internal. The user sees the "Answers per image" lines; you write the Spec.

| Answer in the Goal Card | Spec output `kind` | Evaluator | Pass rule |
| --- | --- | --- | --- |
| one of a fixed set of labels | `label` | `label@1` | `exactMatch == 1` |
| yes or no | `boolean` | `boolean@1` | `exactMatch == 1` |
| several labels at once | `labelSet` | `labelSet@1` | `exactMatch == 1` |
| classifier top class or class set | `label` or `labelSet` | `classification@1` | `exactMatch == 1` |
| how many | `count` | `count@1` | `absoluteDelta <= 0` (or the tolerance the user gave) |
| a measurement | `numeric` | `numeric@1` | `absoluteDelta <= <tolerance>` |
| where things are (boxes) | `positionedObjects` | `objectDetection@1` | `f1 >= <value>` |
| masks | `segmentation` | `segmentation@1` | `meanIou >= 0.8` |
| keypoints | `keypoints` | `keypoints@1` | `keypointAp >= 0.5` |
| time ranges in video | `positionedIntervals` | `intervalCoverage@1` | `coverageIou >= 0.8` |
| fast enough | (no output; `checkKind: runtime`) | `latency@1` with `maxLatencyMs` (required) | `latencyOverBudgetMs <= 0`, or no pass rule to measure only |

Confirm types and configs against `workflow_evals_evaluators_list` for the installed engine
version before writing the Spec. Free text answers have no evaluator: turn them into a label
set or a boolean in the Goal Card, or drop them from scoring and say so. The Spec takes only
`schemaVersion, id, specId, name, inputs, outputs, checks` (no `description`).

## Answers that do not apply everywhere

Some examples cannot carry an answer: no scoreboard on screen, no object to measure. Do not
invent a sentinel value. Mark the Dataset contract field `"optional": true`, leave the field
out of those Cases' ground truth, and give the Check
`"applicability": {"kind": "ground_truth_present", "path": "$.<field>"}`. The engine marks the
Check `not_applicable` on those Cases and they count for nothing. Decide this before creating
any Case: the contract cannot be migrated while a draft Case exists (`gotchas.md`). Put those
examples in a slice (`no-scoreboard`) so the report can show them.

## Concerns to scoring rules

- **"Must never X"** becomes a gate computed from per-Case results: for a boolean answer,
  zero Cases where ground truth is `false` and the candidate said `true` (or the reverse). For
  a label, zero Cases where the candidate said the protected label and ground truth is
  another. For a count, zero Cases with any delta. Compute gates from the export rows; the
  platform does not compute asymmetric costs for you.
- **"Fewer wrong X"** becomes pass rate of that Check.
- **"X is more important than Y"** becomes lexicographic order: compare on X, break ties on
  Y. A difference inside the measured run-to-run noise is a tie (`search.md`).
- **"Exact"** keeps the default pass rule. **"Within N"** sets the tolerance.
- **Simplicity** is a tie-breaker you compute: fewer steps, then fewer model calls, then
  shorter prompt.
- **Speed** is scored in the finalists Run (Phase 5), on a Spec revision that adds
  `latency@1`; a latency check in the search Spec disables execution reuse and triples the
  cost of the rounds. With a budget, the Check has a pass rule; without one it measures.
  Latency measured inside a big joint Run reflects backend load, not the Workflow; only the
  finalists Run is quotable.

Write the resulting rule as the "Better means" list on the Goal Card so the user approves the
order without seeing the mechanics.

## Coverage

Count the examples per answer value as soon as the answer key is drafted. Any value with
fewer than 5 examples gets a line at Checkpoint 2 ("only 3 frames show `done`"), a denser
sample of the same source around those moments when there is one, and otherwise a request
for media that contains it. A ranking that turns on a rare value is reported with that caveat
and, in Phase 5, with reruns and ranges rather than a point.
