# xYang Validator Walkthrough

The validator runs a **three-phase pipeline**: parse the YANG schema, parse the
JSON data, then walk both trees together to check conformance.

## Phase 1: YANG Schema Parsing

### 1.1 Lexer (`xyang/yang/ast/lexer.mojo`)

A hand-written, zero-copy scanner over raw UTF-8 bytes. It classifies the first
byte of every token via a **comptime 256-byte lookup table** into one of 7 token
types: `IDENTIFIER`, `LBRACE`, `RBRACE`, `SEMICOLON`, `PLUS`, `STRING`, `EOF`.
Whitespace and comments are consumed between tokens.

### 1.2 Parser (`xyang/yang/ast/parser.mojo`)

A recursive-descent parser that reads tokens and builds a tree of
`YangConstruct` nodes. Each YANG statement (e.g. `container`, `leaf`, `type`)
becomes one `YangConstruct` with a keyword string, an argument value, and a
`List[Arc[YangConstruct]]` of children.

### 1.3 Spec Validation (`xyang/yang/runtime_spec.mojo`)

After raw parsing, the tree is validated against the RFC 7950 grammar rules. A
dense table of 60 `RuntimeConstructSpec` entries (one per YANG keyword) checks:

- **Argument parsing/typing** — each keyword has a function pointer that
  validates and parses its argument into a typed `Variant` payload (e.g.
  `"1..65535"` becomes `List[RangeBounds]`).
- **Cardinality** — child statement occurrence rules (exactly-one, zero-or-one,
  zero-or-more, etc.).
- Recursively validates every child statement.

### 1.4 Module Indexing (`YangModule._populate_from_validated_root`)

Builds fast lookup maps: `top_containers`, `groupings`, `typedefs`, keyed by
name.

## Phase 2: JSON Data Parsing

`JsonParser` (`xyang/json/parser.mojo`) is another hand-written
recursive-descent parser. It produces a tree of `JsonValue` nodes, each tagged
with a kind (`OBJECT`, `ARRAY`, `STRING`, `INT`, `BOOL`, `NULL`) and carrying
the appropriate fields (object keys/values, array elements, scalar values,
source line numbers).

## Phase 3: Validation

This is where the two trees are walked together.

### 3.1 Top-Level Dispatch (`validate_data`)

Checks the JSON root is an object, then matches each top-level key against
`module.top_containers`.

### 3.2 Recursive Object Validation (`validate_object_against_construct`)

For each JSON key in an object:

- **Schema child resolution** via `find_schema_child_for_json_key` — walks the
  YANG tree including `uses`/grouping expansion and `choice`/`case` branch
  resolution.
- **Dispatches by node kind**: `leaf` → type check, `container` → recurse,
  `list` → array-of-objects check, `leaf-list` → array-of-scalars check.

### 3.3 Leaf Type Checking (`validate_leaf_value`)

Per YANG type:

- **`string`** — checks `length` restrictions (Unicode scalar count), `pattern`
  restrictions (XSD regex subset implemented in pure Mojo with backtracking),
  and `must` constraints.
- **`boolean`** — JSON must be a boolean.
- **`uint16`** — JSON must be an integer in 0–65535, plus explicit `range`
  restriction segments.
- **`enumeration`** — JSON string must match a declared `enum` value (follows
  `typedef` chains).
- **`leafref`** — scalar type check only; actual reference resolution is
  deferred.

### 3.4 List and Leaf-List Validation

Lists must be JSON arrays of objects; each entry is recursively validated and
checked for required `key` leaves. Leaf-lists must be JSON arrays of scalars,
each type-checked.

### 3.5 Choice/Case Enforcement (`schema_walk.mojo`)

Mandatory `choice` nodes must have at least one `case` satisfied. Ambiguous
cases (multiple branches match) raise an error.

### 3.6 Leafref Resolution (`xyang/validator/leafref.mojo`)

A **separate post-validation pass** that walks the JSON tree looking for
`leafref` leaves, parses their `path` argument (supporting `../`, absolute
paths, and `[key=current()/../field]` predicates), resolves the path against
the JSON document, and checks that the leaf's actual value exists in the
resolved target set. Results are cached in a `LeafrefCache`.

## Key Data Structures

| Structure | Role |
|---|---|
| `YangConstruct` | Universal AST node for every YANG statement |
| `YangArgumentValue` | Canonical text + typed `Variant` payload |
| `YangModule` | Parsed module with indexed lookup maps |
| `RuntimeConstructSpec` | Per-keyword grammar rules + argument parser |
| `JsonValue` | JSON AST node (object/array/scalar) |
| `LeafrefCache` | Memoized leafref path resolutions |

## Pattern Matching (`xyang/validator/pattern_match.mojo`)

Implements a **subset of XSD regular expressions** (RFC 7950 section 9.4.5)
directly in Mojo — no external regex library. Supports:

- `.` (any character), `[...]` character classes with `^` negation and `a-z`
  ranges
- Quantifiers: `*`, `+`, `?`, `{n}` (exact repetition)
- `\` escapes (including `\d` for digits)
- Leading `^` / trailing `$` anchors (stripped, since XSD patterns match the
  entire string)
- Full UTF-8 scalar decoding for multi-byte characters

The matcher uses recursive backtracking over the pattern and input string.
