"""Fill the fixed pricing template with already verified, current facts."""

import argparse
import json
from pathlib import Path
import re
import sys


TEMPLATE = Path(__file__).resolve().parents[1] / "assets" / "pricing-template.md"
PLACEHOLDER = re.compile(r"\{\{([a-z_]+)\}\}")


def render(facts):
    template = TEMPLATE.read_text(encoding="utf-8")
    required = set(PLACEHOLDER.findall(template))
    if not isinstance(facts, dict) or set(facts) != required:
        raise ValueError("Provide exactly these fields: " + ", ".join(sorted(required)))
    for name, value in facts.items():
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{name} must be a nonempty string")
        if "{{" in value or "}}" in value:
            raise ValueError(f"{name} contains an unresolved placeholder")
    # Callable replacement preserves literal backslashes and never re-evaluates values.
    return PLACEHOLDER.sub(lambda match: facts[match.group(1)], template)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("facts", type=Path, help="JSON object of freshly verified template fields")
    args = parser.parse_args()
    try:
        result = render(json.loads(args.facts.read_text(encoding="utf-8")))
    except (OSError, ValueError) as error:
        parser.exit(1, f"Cannot render pricing: {error}\n")
    sys.stdout.write(result)


if __name__ == "__main__":
    main()
