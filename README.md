# xYang.mojo

xYang is a semantic modeling framework for the Mojo ecosystem.

It brings YANG-derived semantics — ranges, conditional presence, referential integrity, cross-field invariants, list keys, and schema constraints — into Mojo’s type system and compile-time execution model.

Rather than treating schemas as external JSON documents validated at runtime, xYang models them as executable semantic structures:

* parametric Mojo types carry schema constraints,
* compile-time validation verifies structural correctness early,
* runtime validators enforce the same invariants at service boundaries,
* generated JSON Schema and OpenAPI artifacts become projections of a single semantic source of truth.

The project explores a broader idea:

> semantic contracts should participate in compilation.

---

## Why xYang?

Most modern AI and API systems still rely on:

* JSON Schema as loosely-coupled metadata,
* runtime validators,
* handwritten function declarations,
* prompt-level constraint enforcement,
* duplicated schema definitions across services and tooling.

This works for structural validation, but breaks down for richer semantic relationships:

* conditional presence (`when`)
* cross-field invariants (`must`)
* referential integrity (`leafref`)
* constrained enumerations derived from live data models
* hierarchical constraints spanning composite objects

YANG (RFC 7950) was designed to model these semantics explicitly.

xYang uses a subset of YANG — focused on data modeling rather than NETCONF transport — as a semantic intermediate representation for Mojo services and AI-facing APIs.

Where JSON Schema primarily describes shape, YANG can describe meaning.

---

## Core Ideas

### Compile-time semantic modeling

A constraint is not metadata attached to a type.

The constraint *is part of the type*.

```mojo
comptime Age = YangLeaf[
    YangBuiltinUInt8,
    YangConstraints[
        Range=YangRange[18, 120]
    ]
]
```

Constraint violations surface during compilation via `comptime assert`, not only at runtime.

---

### Schema-grounded inference

xYang is designed for AI-native systems where structured generation matters.

Instead of:

* generating broadly,
* validating afterward,
* retrying on failure,

xYang enables:

* deriving constrained schemas from domain models,
* propagating valid value sets into function declarations,
* restricting the model’s generation space before inference begins.

The goal is not prompt engineering.

The goal is semantic constraint propagation.

---

### YANG as semantic IR

xYang treats YANG as a semantic intermediate representation:

* YANG is the canonical semantic model,
* JSON Schema and OpenAPI are lowerings,
* Mojo types are executable semantic representations.

This follows the same architectural principle as compiler IR systems such as MLIR:
one semantic source of truth, multiple projections.

---

## Current Status

xYang is still experimental, but several major pieces already exist:

* YANG AST and schema model
* JSON Schema + `x-yang` parser
* text YANG parser
* compile-time schema validation
* runtime validator
* XPath tokenizer/parser/evaluator for `must` and `when`
* JSON Schema generation
* composable constraint descriptors
* pure-Mojo regex engine for RFC 7950 patterns
* shopping cart demo with compile-time validation gates

The project is actively exploring:

* semantic modeling patterns in Mojo,
* compile-time schema specialization,
* schema-grounded LLM inference,
* executable semantic infrastructure.

---

## Repository Layout

```text
xyang/
├── ast.mojo          # YANG AST and schema model
├── json/             # JSON Schema + x-yang parsing and lowering
├── yang/             # Text YANG parser
├── validator/        # Runtime validation engine
├── xpath/            # XPath tokenizer, parser, evaluator
└── ...
```

Additional components:

```text
main.mojo             # CLI entry point
examples/             # Example schemas and demos
alternatives/         # Experimental parser implementations
```

---

## Build Workflow

### Build the precompiled package

```bash
pixi run package
```

Produces:

```text
build/xyang.mojopkg
```

Manual equivalent:

```bash
mkdir -p build
mojo package -I. -o build/xyang.mojopkg xyang
```

---

## Fast Development Workflow

For day-to-day iteration, use the precompiled mojopkg instead of rebuilding all sources repeatedly.

```bash
pixi run package
pixi run compile-check
```

This performs a fast compile against:

```text
build/xyang.mojopkg
```

without recompiling the entire repository from source.

For targeted runs:

```bash
mojo -I build -I .pixi/envs/default/lib/mojo myfile.mojo
```

---

## Running Tests

Fast check:

```bash
pixi run compile-check
```

Broader regression against the precompiled package:

```bash
pixi run tests-mojopkg
```

Full source-based regression:

```bash
pixi run tests
```

Run tests from the repository root when examples use relative paths.

---

## Using xYang

Import the package using:

```bash
mojo build -I build myapp.mojo
```

or set:

```bash
MODULAR_MOJO_IMPORT_PATH=build
```

Example:

```mojo
from xyang import parse_json, parse_yang_json, parse_yang_json_module
```

Subpackages work like normal Mojo source imports:

```mojo
from xyang.validator.document import validate_data
from xyang.yang.xpath import parse_xpath
```

---

## Long-Term Direction

xYang explores a broader hypothesis:

> AI systems need semantic infrastructure the way compute systems needed compiler infrastructure.

As software generation accelerates, the bottleneck increasingly shifts from code production to semantic coherence:

* explicit constraints,
* machine-checkable invariants,
* executable standards,
* shared meaning between humans and machines.

xYang is an experiment in bringing that semantic layer into the Mojo ecosystem directly through the compiler, the type system, and compile-time execution.
