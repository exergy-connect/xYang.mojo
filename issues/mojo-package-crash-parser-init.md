# Mojo packaging crash triage: `_YangParser` in `__init__.mojo`

## Symptom
`pixi run package` intermittently crashed with `exit 139` (segfault) inside:

`mojo package -I. -o build/xyang.mojopkg xyang`

The crash occurred before normal compile diagnostics and was reproducible on `main` after the parser-split refactor.

## What changed
We moved the heavy parser implementation out of package initializer scope:

- Moved full `_YangParser` implementation from:
  - `xyang/yang/parser/__init__.mojo`
- Into:
  - `xyang/yang/parser/parser.mojo`

`xyang/yang/parser/__init__.mojo` now only exposes the public wrapper API:

- `tokenize_yang`
- `parse_yang_string`
- `parse_yang_file`

and imports `_YangParser` from `xyang.yang.parser.parser`.

## Why this helps
Mojo appears sensitive to elaborating very large, deeply connected symbols from `__init__.mojo` during `mojo package` graph construction.

By reducing `__init__.mojo` to a thin API facade and moving `_YangParser` + its broad import surface into a normal module (`parser.mojo`), we avoid that problematic initialization/elaboration path while preserving behavior.

## Validation
Post-change verification in this workspace:

- `pixi run package` repeated 6 times: all succeeded (`run1..run6 = 0`)
- Targeted parser behavior check:
  - `pixi run mojo -I . tests/yang/test_uses_refine_augment.mojo`
  - Passed (`1 passed, 0 failed`)

## Notes
This documents a practical structural workaround for a compiler crash path.
If the upstream compiler bug is fixed, `_YangParser` could potentially be moved back, but current layout is stable and keeps packaging reliable.
