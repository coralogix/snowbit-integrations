#!/usr/bin/env python3
"""
Coralogix Parser Builder CLI - Create parsers for any log source.
Identify, generate, deploy. Use in any Cursor project.

Usage:
  python cli.py identify <log_sample_file>
  python cli.py generate [--source SOURCE_ID] [--sample FILE] [-o OUTPUT]
  python cli.py deploy [--source SOURCE_ID] [--sample FILE] [--rule-file FILE]
  python cli.py add-source <sample_file> [--id ID] [--name NAME]
  python cli.py list-sources
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

# Ensure we can import parser from same directory
sys.path.insert(0, str(Path(__file__).parent))

from parser import (
    identify_log_source,
    load_log_sources,
    generate_parser,
    list_sources,
    add_log_source,
    analyze_log_format,
)
from deploy_mgmt_api import deploy_from_dict


def read_sample(path: str) -> str:
    """Read log sample from file or stdin."""
    if path == "-":
        return sys.stdin.read()
    p = Path(path)
    if not p.exists():
        print(f"Error: File not found: {path}", file=sys.stderr)
        sys.exit(1)
    return p.read_text()


def cmd_identify(args):
    sample = read_sample(args.sample)
    if not sample.strip():
        print("Error: Empty log sample", file=sys.stderr)
        sys.exit(1)

    log_sources = load_log_sources()
    matches = identify_log_source(sample, log_sources)

    if not matches:
        print("No matching log source found.")
        print("Try: python cli.py generate --sample <file>  (auto-detects format)")
        print("Or:  python cli.py add-source <file> --id my_source  (register for reuse)")
        return

    print(f"Top match: {matches[0]['source']['name']} ({matches[0]['confidence']}%)")
    for i, m in enumerate(matches[:5], 1):
        print(f"  {i}. {m['source']['name']} - {m['confidence']}%")


def cmd_generate(args):
    sample = read_sample(args.sample) if args.sample else ""
    source_id = args.source or ""

    if not sample and not source_id:
        print("Error: Provide --sample FILE or --source SOURCE_ID", file=sys.stderr)
        print("  python cli.py generate --source nginx_access", file=sys.stderr)
        print("  python cli.py generate --sample mylog.txt", file=sys.stderr)
        sys.exit(1)

    result = generate_parser(log_sample=sample, source_id=source_id or None)

    if args.output:
        Path(args.output).write_text(json.dumps(result["rule_group"], indent=2))
        print(f"Parser saved to {args.output}")
    else:
        print(json.dumps(result["rule_group"], indent=2))


def cmd_deploy(args):
    api_key = args.api_key or os.environ.get("CORALOGIX_API_KEY")
    endpoint = args.endpoint or os.environ.get("CORALOGIX_ENDPOINT", "eu1.coralogix.com")

    if not api_key:
        print("Error: API key required. Set CORALOGIX_API_KEY or use --api-key", file=sys.stderr)
        sys.exit(1)

    sample = read_sample(args.sample) if args.sample else ""
    source_id = args.source or ""

    if args.rule_file:
        rule_group = json.loads(Path(args.rule_file).read_text())
    elif sample or source_id:
        result = generate_parser(log_sample=sample, source_id=source_id or None)
        rule_group = result["rule_group"]
    else:
        print("Error: Provide --rule-file, --sample, or --source", file=sys.stderr)
        sys.exit(1)

    try:
        deploy_from_dict(rule_group, api_key, endpoint)
        print(f"✓ Deployed: {rule_group.get('name', 'parser')}")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        print("\nTip: Ensure your API key has PARSINGRULES role. Regions: eu1.coralogix.com, cx498.coralogix.com, etc.", file=sys.stderr)
        sys.exit(1)


def cmd_list(args):
    sources = list_sources()
    for s in sources:
        print(f"  {s['id']:25} {s['name']}")


def cmd_add_source(args):
    """Add a new log source from sample. Auto-detects format and adds to log_sources.json."""
    sample = read_sample(args.sample)
    if not sample.strip():
        print("Error: Empty log sample", file=sys.stderr)
        sys.exit(1)

    source_id = args.id or "custom_" + str(abs(hash(sample[:200])) % 10000)
    source_id = re.sub(r"\W", "_", source_id).lower()[:50]
    name = args.name or f"Custom {source_id}"
    description = args.description or ""

    analysis = analyze_log_format(sample)
    print(f"Detected format: {analysis['format_type']}")

    try:
        new_source = add_log_source(
            source_id=source_id,
            name=name,
            description=description,
            sample_log=sample[:2000],
            parser_type=args.parser_type or "generic",
        )
        print(f"✓ Added: {new_source['id']} ({new_source['name']})")
        print(f"  Edit data/log_sources.json to customize patterns.")
        print(f"  Generate parser: python cli.py generate --source {new_source['id']}")
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Coralogix Parser Builder - identify, generate, deploy")
    sub = parser.add_subparsers(dest="cmd", required=True)

    # identify
    p_identify = sub.add_parser("identify", help="Identify log source from sample")
    p_identify.add_argument("sample", nargs="?", default="-", help="Log sample file or - for stdin")
    p_identify.set_defaults(func=cmd_identify)

    # generate
    p_gen = sub.add_parser("generate", help="Generate parser JSON")
    p_gen.add_argument("--sample", "-s", help="Log sample file or - for stdin")
    p_gen.add_argument("--source", help="Known source ID (e.g. nginx_access)")
    p_gen.add_argument("--output", "-o", help="Output file (default: stdout)")
    p_gen.set_defaults(func=cmd_generate)

    # deploy
    p_deploy = sub.add_parser("deploy", help="Deploy parser to Coralogix")
    p_deploy.add_argument("--sample", "-s", help="Log sample file")
    p_deploy.add_argument("--source", help="Known source ID")
    p_deploy.add_argument("--rule-file", "-f", help="Pre-generated rule JSON file")
    p_deploy.add_argument("--api-key", "-k", help="Coralogix API key (or CORALOGIX_API_KEY)")
    p_deploy.add_argument("--endpoint", "-e", help="Coralogix endpoint (default: eu1.coralogix.com)")
    p_deploy.set_defaults(func=cmd_deploy)

    # list-sources
    p_list = sub.add_parser("list-sources", help="List supported log sources")
    p_list.set_defaults(func=cmd_list)

    # add-source
    p_add = sub.add_parser("add-source", help="Add new log source from sample (any format)")
    p_add.add_argument("sample", help="Log sample file or - for stdin")
    p_add.add_argument("--id", help="Source ID (default: auto-generated)")
    p_add.add_argument("--name", help="Display name")
    p_add.add_argument("--description", help="Description")
    p_add.add_argument("--parser-type", default="generic", help="Parser type (default: generic for auto-detect)")
    p_add.set_defaults(func=cmd_add_source)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
