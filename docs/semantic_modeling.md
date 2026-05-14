# xYang: Semantic Modeling for the Mojo Ecosystem

## Project Summary

Mojo has a powerful story for compute — compilers as a means to generalization, composability, and collaboration. What it doesn't yet have is a principled layer for semantic modeling: a way to describe what data means, what constraints hold, and what a service promises — verified early, not discovered at runtime.

xYang brings that layer to Mojo. It is a semantic modeling framework that encodes YANG-derived type descriptors — leaf types, ranges, string constraints, when conditions, must expressions, list keys — as first-class Mojo parametric types, resolved at compile time. A Mojo application that uses xYang carries its schema in its type system. Constraint violations are type errors, not runtime exceptions.

## The Problem

Today, LLM-powered services validate their API contracts ad-hoc: JSON schemas as strings, function declarations hand-written, auto-generated and untested, enum values hardcoded against a data model that may have drifted. When a Gemini function call returns an unexpected value, or an LLM hallucinates a parameter that was never valid, the error surfaces at the worst possible moment — after inference, inside application logic just before interacting with a user.

This is the same problem compilers solved for GPU compute. Manually written CUDA kernels are fast but brittle, opaque to anyone who didn't write them, and resistant to generalization. The answer was not better kernels — it was a generalized compiler that encodes domain knowledge into the artifact.

xYang applies that same insight one layer up: to the semantic contracts between services, data models, and LLMs.

## Why YANG as the Semantic Foundation

YANG (RFC 7950) is not a networking protocol. It is a data modeling language — one that has spent fifteen years being stress-tested against the hardest operational requirements in production infrastructure: hierarchical data with cross-references, invariants that must hold across composite objects, conditional presence, enumeration constraints, and range restrictions, all expressed in a single modular schema that drives both validation and documentation. Where JSON Schema describes shape, YANG describes meaning: `must` expressions assert semantic invariants across the tree, `when` conditions make fields conditionally present based on sibling values, `leafref` enforces referential integrity across containers. These are not features JSON Schema has.

Critically, YANG is a semantic IR from which target-specific representations can be derived. xYang already parses YANG-annotated JSON Schema (`x-yang` extensions) and will emit JSON Schema and OpenAPI from the same model. The YANG type system is the source of truth; the LLM API artifact is a projection of it. This is the same principle as MLIR: one well-designed intermediate representation, multiple lowerings. xYang uses a subset of YANG — not the NETCONF transport machinery, not the management plane protocols, just the data modeling core — as that intermediate representation for Mojo service semantics. A mature, open, RFC-backed standard chosen not for its domain of origin but for its semantic expressiveness, which is unmatched among open schema languages.

## The Architecture

The full system is structured as a three-layer stack:

**xYang (Mojo)** — the meta-layer. YANG-derived constraints encoded as parametric types. A `YangLeaf[YangBuiltinUInt8, YangConstraints[Range=YangRange[18,120]]]` is not a comment or a doc string — it is a type. Constraint violations surface at compile time via `comptime assert`. The type system generates a validator; the validator does not generate the type.

**xFrame** — a domain modeling framework whose meta-model is grounded in xYang. Entities, foreign keys, composite primary keys, and enum constraints are modeled as first-class schema objects. xFrame derives the valid value set for each enum from a consolidated JSON data model compiled during CI/CD — so the Mojo binary that ships encodes exactly the constraints that the current data supports.

**PhilateLister** — a working LLM-powered application built on xFrame. A stamp dealer assistant that calls Gemini with function declarations derived from the xFrame model. The valid enum values offered to the LLM — country identifiers, catalog SKUs, issue types — are propagated from the data files into the function schema at build time. The model cannot hallucinate a country that isn't in the catalog, because that country is not in its choice set. This is application domain constraint propagation into the model's decision space, not prompt engineering.

## What Build-Time Specialization Means

When the stamp catalog changes, CI/CD recompiles the consolidated JSON data model, xFrame derives updated enum constraints, and the Mojo binary is rebuilt with those constraints encoded. The LLM always operates against a specialized binary — not a generic one patched at runtime with hope.

This is the orthogonality and composability that makes generalized systems preferable to hand-tuned ones: the derivation process is principled, so it works for any catalog, any provider, any function schema. Changing the data model updates the constraints automatically. There is no separate validation layer to keep in sync.

## Why This Cannot Be Done as Well in Any Other Language

The question a skeptical reviewer should ask: why isn't this just a Python codegen script that emits JSON Schema? Or a Rust macro crate? Or a TypeScript validator?

The answer is that xYang's guarantees are not portable to those languages without losing what makes them guarantees.

**Parametric types as the constraint carrier.** In Python or TypeScript, a range constraint is metadata — a dict entry, a decorator argument, a comment. It exists at runtime or is erased entirely. In Mojo, `YangRange[0, 65535]` is a type parameter. It participates in overload resolution, trait conformance, and comptime evaluation. The constraint is the type; there is no runtime object that could be wrong or missing.

**Comptime execution over the full parser.** `comptime_validate` runs the YANG schema parser — a complete recursive-descent parser over UTF-8 bytes — at compile time, against the struct's declared field types. This is not a macro that pattern-matches syntax; it is full program execution during compilation. Rust macros operate on token streams. Python decorators run at import time with no compiler integration. Mojo's comptime makes the parser itself a compile-time tool.

**Zero-cost specialization.** `yang_module_from_model[CartContainer]` generates a `YangModule` from the struct's type descriptors with no runtime overhead — the module is fully determined by the types, resolved at compile time, with static dispatch throughout. In a dynamic language, this requires reflection at runtime. In a compiled language without parametric metaprogramming, it requires a separate codegen step outside the language. In Mojo, it is a generic function call.

**Ahead-of-time schema specialization as a first-class build artifact.** The CI/CD pipeline that compiles enum constraints from the live data model into the Mojo binary is not a workaround — it is Mojo's intended model for AI inference infrastructure. A Mojo binary is not a script that validates at startup; it is a compiled artifact where the valid value set is encoded in the types. This is the same principle Mojo applies to kernel specialization for hardware targets: compile-time knowledge produces better, safer artifacts than runtime discovery.

**Unified systems and AI runtime.** Mojo's ambition is to be the language where the kernel and the service live in the same codebase, with the same performance model, the same type system, the same build toolchain. xYang puts the semantic contract layer in that same space — not in a sidecar Python service, not in a YAML file processed by a separate tool, but in Mojo types that the compiler verifies. No other language is simultaneously targeting systems-level performance, AI inference infrastructure, and the expressiveness needed to make this work without a runtime tax.

xYang is not portable middleware. It is infrastructure that only makes sense inside Mojo's specific combination of capabilities — and that demonstrates those capabilities working together in a non-trivial domain.

## What Exists Today

The following are ordered by strategic significance, not implementation chronology.

**`comptime_validate`** — schema conformance as a compile error. A Mojo struct declares its YANG shape via parametric type descriptors. `comptime_validate` runs the full YANG schema parser at compile time and checks the struct's field declarations against it. A field rename, type mismatch, or constraint violation does not produce a runtime error — it does not compile. This is the central guarantee: structural correctness is a property of the binary, not a property of the test suite.

**`yang_module_from_model`** — self-describing types. Given only a Mojo struct's type descriptors, this function generates a complete `YangModule` — a validated, queryable schema object. The struct does not reference an external schema file at runtime; it *is* the schema. Services built on xYang can expose their own schema to clients, tools, and gateways without maintaining a separate document.

**xFrame constrained generation pipeline** — schema-grounded LLM inference. The most consequential capability in the stack today is not in the Mojo type system — it is what the type system makes possible at the application layer. xFrame derives Gemini function declarations from the modeled entity schema, propagating live database values into parameter enum constraints at build time. The LLM receives only the values that exist in the catalog. It cannot hallucinate a country, catalog SKU, or issue type that is not in the data, because those values are absent from its choice set — not warned against, not filtered after the fact, structurally absent.

This is schema-grounded inference: the model's generation space is constrained by the data model before inference begins. As agentic systems become more complex — multi-step tool calling, chained function invocations, structured output pipelines — the failure mode is not capability but reliability. An agent that can call the right tool but hallucinate a parameter value is not a reliable agent. xYang's contribution to agent tool reliability is not prompt engineering; it is formal constraint propagation from the data model into the tool declaration. The correctness guarantee holds regardless of model, provider, or prompt.

**Runtime validation** — the closing envelope. Incoming JSON is validated against the schema on every request — type checks, range restrictions, choice/case enforcement, and leafref referential integrity — before it reaches application logic. Outgoing responses are validated against the same schema before they leave the service. The LLM cannot produce a structurally invalid response that propagates downstream.

**Foundation** — parser and type system. A complete YANG schema parser (hand-written, zero-copy, UTF-8) and JSON parser in Mojo; a pure-Mojo XSD regex engine supporting the full RFC 7950 pattern subset; composable constraint traits for ranges, string lengths, when conditions, and must expressions; a working shopping cart demo with three `comptime assert` gates that verify schema parse, struct reflection, and round-trip validation before the binary is produced.

## What the Grant Would Support

The grant would support packaging, documentation, and publication of xYang as an early semantic modeling toolkit for the Mojo ecosystem, including a working schema-derived LLM function-calling demo and initial JSON Schema export support.

Concretely, the public artifacts would be:

- A documented, reproducible demo — shopping cart and Gemini function-calling — showing the full comptime → runtime → constrained-LLM pipeline, cloneable and runnable by any Mojo developer
- JSON Schema export from `yang_module_from_model`, so a Mojo struct annotated with xYang descriptors generates the artifact that LLM function-calling APIs consume directly
- A pixi-packaged, installable release of xYang with a `pixi run demo` entry point and annotated source

The substantial prior work — parser, type system, comptime validation, runtime validator, xFrame pipeline — is already in place. The grant accelerates community access to a working foundation.

## Why This Fills a Real Gap

The Mojo ecosystem has strong coverage of compute — kernels, model bringup, hardware abstraction. It has no semantic modeling layer. Every Mojo service that exposes an API, calls an LLM, or validates incoming data currently does so with ad-hoc logic.

xYang gives that layer a principled foundation: open-standard derived, compile-time verified, self-describing at runtime. It makes Mojo viable not just for the engineers writing kernels, but for the engineers designing the services that kernels run inside — expanding who can participate in the Mojo ecosystem, with the kind of abstraction that compilers exist to provide.

---

*xYang is developed by Exergy ∞ LLC. The xyang repository, shopping cart demo, and PhilateLister application are available on GitHub.*
