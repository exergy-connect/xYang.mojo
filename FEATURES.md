# xYang.mojo Feature Coverage (RFC 7950)

This document tracks current feature coverage against YANG 1.1 (RFC 7950).

Status labels:
- `Supported`: implemented and used in current parser/validator flow.
- `Partial`: some behavior exists, but not RFC-complete.
- `Not yet`: not implemented (or currently ignored by parser/validator).

Scope:
- Code under `xyang/` (text YANG parser, JSON/YANG parser, JSON Schema generator, AST, XPath, validator).
- Focus is runtime behavior, not just syntax acceptance.

## RFC Construct Matrix

### Module/meta statements
| Construct | Status | Notes |
|---|---|---|
| `module` | Supported | Parsed and represented in AST. |
| `namespace` | Supported | Parsed in text parser and JSON/YANG path. |
| `prefix` | Supported | Parsed in text parser and JSON/YANG path. |
| `revision` | Partial | All `revision` dates collected in `YangModule.revisions` (source order). Substatements inside each revision block are still skipped; no per-revision object in the AST. |
| `description` | Partial | Module-level string on `YangModule`; also captured on several data nodes (e.g. `container`, `list`). Not every statement kind stores description yet. |
| `organization`, `contact` | Supported | Module-level strings on `YangModule` from the text parser (with `get_organization` / `get_contact`). JSON/YANG import leaves them empty until the meta-model exposes them. |

### Data definition statements
| Construct | Status | Notes |
|---|---|---|
| `container` | Supported | Parsed, represented, validated structurally. |
| `list` | Supported | Parsed, represented, basic structural validation. |
| `leaf` | Supported | Parsed, represented, type/constraint checks apply. |
| `choice` | Supported | Parsed; `when` on the choice is captured and evaluated in the validator; mandatory choice check implemented. |
| `case` | Supported | Parsed under choice as case-name set. Explicit `case { ... }` blocks may include `when` in the text parser (as well as JSON Schema / JSON round-trip); validator evaluates case `when` when that case is active. |
| `leaf-list` | Supported | Dedicated AST node and text-parser support; validator enforces array shape plus per-item type/leafref/must checks. |
| `anydata`, `anyxml` | Supported | Parsed into AST; JSON Schema uses open instance `type` array plus `x-yang.type` (`anydata` / `anyxml`); validator enforces presence/mandatory, `when`, and `must` only (instance JSON unconstrained). Bodies accept `if-feature` and prefixed extensions like Python xYang. Optional draft subtree validation is not implemented (CLI flags remain unavailable). |
| `grouping` | Supported | Text parser parses and stores groupings and supports grouped schema nodes used by this project (`leaf`, `leaf-list`, `container`, `list`, `choice`). |
| `uses` | Partial | Text parser expands `uses` in `container`/`list`/`grouping` for in-module groupings and applies `refine` plus `augment` substatements; `if-feature` is parsed/accepted but feature resolution is not yet enforced. |
| `augment` | Partial | Text parser applies `augment` for in-module targets (including absolute module paths and relative paths under `uses`) for supported node kinds. |
| `rpc`, `action`, `notification` | Not yet | Not modeled/validated. |
| `deviation`/`deviate` | Not yet | Not modeled/validated. |

### Type system
| Construct | Status | Notes |
|---|---|---|
| Base scalar names (`string`, integer types, `boolean`, etc.) | Supported | Type-name based validation for a practical subset. |
| Integer fixed-width bounds | Supported | int8/int16/int32, uint8/uint16/uint32/uint64 enforced. |
| `range` on numeric type | Supported | Single interval (`min..max`) extracted and enforced (integers; `decimal64` uses a float range in the AST). |
| `leafref` type | Supported | Scalar-type check plus referential integrity validation against resolved target values when `require-instance` is true. |
| `enumeration` / `enum` | Supported | Enum labels in AST; string value must match a declared `enum` (text and JSON). |
| `union` | Partial | Member types in AST; validator tries each member (same as “first matching branch” for instance data). Text parser and JSON `oneOf` round-trip. |
| `decimal64` | Partial | `fraction-digits` and `range` parsed in text YANG; JSON Schema uses `number`, optional `multipleOf`, `minimum`/`maximum`, `x-yang` with `fraction-digits`. Validator checks numeric value and range; does not fully enforce fraction-digit string form of every value. |
| `bits` | Partial | `bit` names from text YANG; instance value is a string of space-separated bit names; validator checks against declared bits. No `position` ordering semantics beyond name list. |
| `identityref` | Partial | `base` stored in AST (text and `x-yang` in JSON); validator treats instance as a string (no resolution of identity-derived names against `identity` statements in the module tree). |
| `path` and `require-instance` leafref substatements | Supported | Parsed from text YANG and JSON/YANG metadata; used by validator for leafref target resolution and enforcement. |

### Constraints
| Construct | Status | Notes |
|---|---|---|
| `must` on leaf | Supported | Parsed, XPath AST compiled (when parseable), evaluated at validation. |
| `must` `error-message` | Supported | Used in reported validation errors. |
| `when` on `leaf` | Supported | Parsed and enforced for present leaves. |
| `when` on `choice` / `case` | Supported | Parsed from text YANG and JSON metadata; `x-yang` in generated JSON Schema carries the expressions; validator evaluates against the parent object (choice: before branch resolution; case: when the case is the active branch). |
| `mandatory` (leaf) | Supported | Missing/null checks implemented. |
| `default` (`leaf`, `leaf-list`, `choice` default case) | Partial | Parser captures defaults; validator realizes leaf/leaf-list effective defaults and treats choice default case as active when no explicit case is present. |
| `key` (list) | Supported | Parsed and used for list-path formatting in diagnostics. |
| `min-elements`, `max-elements`, `unique`, `ordered-by` | Not yet | Not implemented. |
| Choice/case full RFC semantics | Partial | Mandatory choice, default case, and `when` on `choice`/`case` are implemented in parser + validator; other subtleties of RFC 7950 `choice`/`case` are still simplified. |

### XPath support used by `must`/`when`
| Construct | Status | Notes |
|---|---|---|
| Literals (number/string), names | Supported | Parsed/evaluated. |
| Operators `or`, `and`, comparisons, `+`, `-`, path composition `/` and `//` | Supported | `//` is treated like `/` (no true descendant axis; paths are a single string trail per the validator’s `XPathNode` model). |
| Path steps `.`, `..`, `/a/b`, relative `a/b`, and `[` `]` predicates | Supported | Location paths start at the context root; steps join without spurious `//` under `/`. Boolean and numeric (1-based index) predicates; `position()` and `last()` match the current predicate’s node set. Still not a real XML tree: no document-order sibling sets beyond what the model materializes. |
| Functions: `current`, `true`, `false`, `not`, `count`, `string`, `number`, `boolean`, `position`, `last`, `string-length` | Partial | `position`/`last` are correct inside step predicates; `count`/`string`/`not`/etc. follow the string/path model above. |
| Full XPath 1.0 compatibility | Not yet | Many functions/semantics are missing or simplified. |

## Validator Coverage (Current)

Implemented:
- Unknown field detection in containers/list entries.
- Mandatory leaf missing/null checks.
- List node type checks (must be array).
- Leaf-list node type checks (must be array).
- Numeric type + `range` checks; `union` (member types), `decimal64` (range), `bits` (space-separated names), `identityref` (string check).
- Leaf-level `must` and `when` evaluation.
- Leaf-list per-item `must` and type checks.
- Basic choice mandatory check.
- `when` on `choice` and `case` (evaluated in validator when the choice or active case is in play).
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

## JSON Schema Generation (YANG → JSON Schema)

Supported:
- Emit draft marker (`$schema: https://json-schema.org/draft/2020-12/schema`) and top-level `properties`.
- Emit `x-yang` annotations for module metadata and node-level semantics used by this project (`type`, `key`, `mandatory`, `must`, `when`, leafref path/require-instance, and for `decimal64` / `bits` / `identityref` the `fraction-digits`, `bits` name list, and `base` where set).
- Encode integer types and explicit `range` as JSON Schema `minimum`/`maximum`.
- Encode `union` as JSON Schema `oneOf` of member type schemas; `decimal64` as `number` with optional `multipleOf` and min/max; `bits` and `identityref` as `string` plus `x-yang` metadata.
- Encode defaults for `leaf` and `leaf-list` when values are representable.
- Emit choice structure with `oneOf` branches and `x-yang` choice metadata (including `when` on the choice and on each `case` when set).
- Round-trip path covered by tests: text YANG → AST → JSON Schema JSON text → `parse_json_schema`.

Partial:
- Type mapping is still pragmatic: for example `identityref` is not round-tripped with a full set of allowed identity `derived` values; `decimal64` fraction-digits is not re-validated on every JSON number form; not every YANG `typedef` or facet is preserved in JSON Schema.
- Emission is focused on current validator/parser interoperability, not full reversible fidelity for every RFC statement.

## Practical Use Guidance

Good fit today:
- Lightweight schema/data experimentation.
- Basic structural + scalar validation.
- Simple `must` / `when` checks (leaves, and `when` on choices and explicit cases where modeled).
- Integer range enforcement.
- `union` members, `decimal64` (numeric + range), `bits` and `identityref` (within the limitations above).

Not production-complete yet for:
- Full RFC 7950 conformance.
- Advanced module composition (`deviation`, full feature-resolution for `if-feature`, and remaining RFC edge cases in `grouping`/`uses`/`augment`).
- Resolving `identityref` / `bits` / `union` to full RFC 7950 data-model rules (e.g. identity heritage, all `typedef` and facet combinations).
- Full XPath semantics.

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
