PYTHON ?= python3
AGENT ?= claude
SUITE ?= smoke
BASE ?=
CANDIDATE ?=
EVAL_ARGS ?=

.PHONY: eval eval-dry-run eval-list

eval:
	$(PYTHON) evals/scripts/run_eval.py --suite $(SUITE) --agent $(AGENT) $(if $(BASE),--base $(BASE),) $(if $(CANDIDATE),--candidate $(CANDIDATE),) $(EVAL_ARGS)

eval-dry-run:
	$(PYTHON) evals/scripts/run_eval.py --suite $(SUITE) --agent $(AGENT) --dry-run $(if $(BASE),--base $(BASE),) $(if $(CANDIDATE),--candidate $(CANDIDATE),) $(EVAL_ARGS)

eval-list:
	$(PYTHON) evals/scripts/run_eval.py --suite $(SUITE) --list
