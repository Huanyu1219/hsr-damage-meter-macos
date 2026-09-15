#!/usr/bin/env python3
"""Validate the shared contract and both directions of the Rust/Swift boundary."""
import json
import subprocess
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ROOT / 'protocol/schema'
resources = []
for path in sorted(SCHEMAS.glob('*.schema.json')):
    schema = json.loads(path.read_text())
    schema['$id'] = path.as_uri()
    Draft202012Validator.check_schema(schema)
    resources.append((path.as_uri(), Resource.from_contents(schema)))
registry = Registry().with_resources(resources)
validator = Draft202012Validator(
    registry.contents((SCHEMAS / 'envelope.schema.json').as_uri()),
    registry=registry,
    format_checker=FormatChecker(),
)
source = (ROOT / 'protocol/fixtures/sample_session.jsonl').read_text()
expected = [json.loads(line) for line in source.splitlines()]
for event in expected:
    validator.validate(event)
validator.validate(json.loads((ROOT / 'protocol/fixtures/sample_damage.json').read_text()))
invalid = json.loads((ROOT / 'protocol/fixtures/invalid_events.json').read_text())
for case in invalid:
    assert not validator.is_valid(case['event']), case['name']
assert all(a['sequence'] < b['sequence'] for a, b in zip(expected, expected[1:]))

# Optional null and absence mean the same thing in v1; encoders may omit nulls.
def canonical(value):
    if isinstance(value, dict):
        return {k: canonical(v) for k, v in value.items() if v is not None}
    if isinstance(value, list):
        return [canonical(v) for v in value]
    return value

swift_bin = subprocess.check_output(
    ['swift', 'build', '--package-path', str(ROOT / 'macos/HSRDamageMeter'), '--show-bin-path'], text=True
).strip()
commands = {
    'Rust': [str(ROOT / 'collector/target/debug/fixture-roundtrip')],
    'Swift': [str(Path(swift_bin) / 'fixture-roundtrip')],
}
outputs = {}
for name, command in commands.items():
    outputs[name] = subprocess.check_output(command, input=source, text=True)
for name, input_text in [('Rust', outputs['Swift']), ('Swift', outputs['Rust'])]:
    output = subprocess.check_output(commands[name], input=input_text, text=True)
    actual = [json.loads(line) for line in output.splitlines()]
    assert canonical(actual) == canonical(expected), f'{name} cross-language mismatch'
    for event in actual:
        validator.validate(event)
print(f'PASS: 7 schemas, {len(expected)} session events, {len(invalid)} invalid cases; Rust ↔ Swift roundtrips')
