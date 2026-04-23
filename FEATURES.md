# xYang.mojo Feature Coverage (RFC 7950)

This document tracks current feature coverage against YANG 1.1 (RFC 7950).

Status labels:
- `Supported`: implemented and used in current parser/validator flow.
- `Partial`: some behavior exists, but not RFC-complete.
- `Not yet`: not implemented (or currently ignored by parser/validator).

Scope:
- Code under `xyang/` (text YANG parser, JSON/YANG parser, AST, XPath, validator).
- Focus is runtime behavior, not just syntax acceptance.

## RFC Construct Matrix

### Module/meta statements
| Construct | Status | Notes |
|---|---|---|
| `module` | Supported | Parsed and represented in AST. |
| `namespace` | Supported | Parsed in text parser and JSON/YANG path. |
| `prefix` | Supported | Parsed in text parser and JSON/YANG path. |
| `revision` | Partial | Statement recognized; body is skipped, no full revision model. |
| `description` | Partial | Captured for selected nodes only. |
| `organization`, `contact` | Not yet | Accepted as skipped/ignored text statements; not modeled in AST. |

### Data definition statements
| Construct | Status | Notes |
|---|---|---|
| `container` | Supported | Parsed, represented, validated structurally. |
| `list` | Supported | Parsed, represented, basic structural validation. |
| `leaf` | Supported | Parsed, represented, type/constraint checks apply. |
| `choice` | Supported | Parsed; mandatory choice check implemented. |
| `case` | Supported | Parsed under choice as case-name set. |
| `leaf-list` | Supported | Dedicated AST node and text-parser support; validator enforces array shape plus per-item type/leafref/must checks. |
| `anydata`, `anyxml` | Not yet | Not modeled in current Mojo AST/validator path. |
| `grouping` | Not yet | Text parser currently ignores it (statement skipped). |
| `uses` | Not yet | Text parser currently ignores it; no expansion/merge. |
| `augment` | Not yet | No augment processing. |
| `rpc`, `action`, `notification` | Not yet | Not modeled/validated. |
| `deviation`/`deviate` | Not yet | Not modeled/validated. |

### Type system
| Construct | Status | Notes |
|---|---|---|
| Base scalar names (`string`, integer types, `boolean`, etc.) | Supported | Type-name based validation for a practical subset. |
| Integer fixed-width bounds | Supported | int8/int16/int32, uint8/uint16/uint32/uint64 enforced. |
| `range` on numeric type | Supported | Single interval (`min..max`) extracted and enforced. |
| `leafref` type | Supported | Scalar-type check plus referential integrity validation against resolved target values when `require-instance` is true. |
| `identityref`, `union`, `enum`, `bits`, `decimal64`, etc. | Not yet | No RFC-complete support in current Mojo validator path. |
| `path` and `require-instance` leafref substatements | Supported | Parsed from text YANG and JSON/YANG metadata; used by validator for leafref target resolution and enforcement. |

### Constraints
| Construct | Status | Notes |
|---|---|---|
| `must` on leaf | Supported | Parsed, XPath AST compiled (when parseable), evaluated at validation. |
| `must` `error-message` | Supported | Used in reported validation errors. |
| `when` on leaf | Supported | Parsed and enforced for present leaves. |
| `mandatory` (leaf) | Supported | Missing/null checks implemented. |
| `default` (`leaf`, `leaf-list`, `choice` default case) | Partial | Parser captures defaults; validator realizes leaf/leaf-list effective defaults and treats choice default case as active when no explicit case is present. |
| `key` (list) | Supported | Parsed and used for list-path formatting in diagnostics. |
| `min-elements`, `max-elements`, `unique`, `ordered-by` | Not yet | Not implemented. |
| Choice/case full RFC semantics | Partial | Mandatory choice check exists; broader case semantics are simplified. |

### XPath support used by `must`/`when`
| Construct | Status | Notes |
|---|---|---|
| Literals (number/string), names | Supported | Parsed/evaluated. |
| Operators `or`, `and`, comparisons, `+`, `-`, path composition `/` | Supported | Implemented in current evaluator. |
| Path steps `.`, `..`, `/a/b`, predicates | Partial | Works for current simplified path model, not full data-model node semantics. |
| Functions: `current`, `true`, `false`, `not`, `count`, `string`, `number`, `boolean`, `position`, `last`, `string-length` | Partial | Implemented with simplified behavior. |
| Full XPath 1.0 compatibility | Not yet | Many functions/semantics are missing or simplified. |

## Validator Coverage (Current)

Implemented:
- Unknown field detection in containers/list entries.
- Mandatory leaf missing/null checks.
- List node type checks (must be array).
- Leaf-list node type checks (must be array).
- Numeric type + `range` checks.
- Leaf-level `must` and `when` evaluation.
- Leaf-list per-item `must` and type checks.
- Basic choice mandatory check.
- Effective default realization for missing `leaf` / `leaf-list` values.
- Choice default-case handling when no explicit case is active.
- Leafref referential integrity checks (`require-instance`): value must match at least one resolved target from leafref `path` (supports absolute and relative paths in current implementation).

Not implemented yet:
- Presence containers and full config/state semantics.
- Full RFC section 8 behavior for all statement kinds and edit operations.

## JSON/YANG (`.yang.json`) Path

Supported:
- Practical extraction of containers/lists/leaves from `x-yang` metadata.
- `must` and `when` expression capture on leaves.

Partial:
- Feature coverage depends on fields present in `x-yang`; many RFC substatements are not mapped yet.

## Practical Use Guidance

Good fit today:
- Lightweight schema/data experimentation.
- Basic structural + scalar validation.
- Simple `must` / `when` checks.
- Integer range enforcement.

Not production-complete yet for:
- Full RFC 7950 conformance.
- Advanced module composition (`grouping`/`uses`/`augment`/`deviation`).
- Full identityref cross-node integrity and full XPath semantics.

## Notes On Current Leafref Scope

- Implemented and tested:
  - `leafref` scalar type checking.
  - `require-instance true` referential checks.
  - absolute paths (for example `/system/interface/name`).
  - relative paths (for example `../fields/name`).
  - non-string leafref targets (for example integer leaf targets).
- Still simplified versus full RFC/XPath behavior:
  - path traversal currently uses a practical subset of path semantics used by this project.
  - predicate-rich path semantics are not fully RFC/XPath-complete.
