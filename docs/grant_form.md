# xYang.mojo Grant Application

## Project

**xYang.mojo** is a semantic modeling framework for Mojo. It brings a practical subset of YANG-style constraints into Mojo types and compile-time execution, so API schemas can express not just structure, but meaning: ranges, conditional fields, list keys, cross-field invariants, and referential integrity.

The goal is to make Mojo services and AI-facing APIs safer by deriving validators and schema artifacts from one semantic source of truth.

## Applicant

Jeroen van Bemmel / Exergy LLC

## Problem

Mojo has a strong compute story, but applications still need a reliable way to model and validate service contracts. Today this usually means handwritten JSON Schema, runtime-only validators, duplicated API declarations, and prompt-level constraints for LLM tools. Those approaches catch many errors late, after inference or at service boundaries.

xYang explores a compiler-native alternative: encode semantic contracts in Mojo types, validate what can be validated at compile time, and use the same model for runtime validation and generated API schemas.

## Existing Work

The repository already includes:

- A YANG AST and schema model in Mojo
- Text YANG and JSON Schema plus `x-yang` parsing
- Compile-time schema validation experiments
- Runtime JSON data validation
- XPath parsing/evaluation for `must`, `when`, and `leafref`
- JSON Schema generation pieces
- A pure-Mojo pattern matcher for YANG string constraints
- Examples, tests, and a shopping cart demo

The project is experimental, but enough exists to package a useful early developer preview.

## Use of MAX and Mojo

xYang is implemented in Mojo and uses Mojo as the core reason the project is possible. The project is not primarily a MAX kernel or model bringup project. Instead, it focuses on the semantic contract layer around AI-native services: schemas, validators, generated API artifacts, and compile-time checks that help applications call models and expose tools safely.

The Mojo-specific work includes:

- Encoding schema constraints as parametric Mojo types, so ranges, keys, list structure, and semantic annotations participate in type checking instead of living only as runtime metadata
- Running schema validation experiments through Mojo compile-time execution, so some model/schema mismatches can fail before a binary is produced
- Implementing the YANG parser, JSON parser, runtime validator, XPath subset, and pattern matcher directly in Mojo
- Using Mojo ownership, `ArcPointer`, typed structs, `Optional`, traits, and `raises` to build explicit, systems-style schema infrastructure
- Packaging the library and examples with `pixi` against the current Mojo toolchain

The project does not currently involve custom kernel development, GPU kernels, or low-level model bringup. Its relationship to MAX and Mojo is at the application infrastructure layer: it helps developers build reliable Mojo services around models by making tool schemas and API contracts executable, validated, and generated from a single semantic source of truth.

Longer term, this can support MAX-based applications by providing a typed contract layer for model-serving endpoints, structured generation, function-calling APIs, and service boundaries. The same Mojo codebase that runs high-performance compute can also carry the schema logic that validates what data means before and after model inference.

## Grant Request

The grant would support making xYang easier for the Mojo community to try, understand, and extend.

Deliverables:

- Package xYang as an installable Mojo library with a reproducible `pixi` workflow
- Publish a concise walkthrough of the compile-time to runtime validation pipeline
- Finish and document a runnable shopping cart demo showing schema-derived validation
- Add or complete JSON Schema export from modeled Mojo types for LLM function-calling use cases
- Improve tests around the currently supported YANG subset

## Impact

xYang would give Mojo developers an early semantic contract layer for services, structured data, and AI tool interfaces. It also demonstrates a distinctive Mojo capability: using parametric types and compile-time execution to make schemas executable rather than passive metadata.

For the broader ecosystem, this helps position Mojo not only as a language for kernels and performance work, but also as a language for building reliable, meaningful AI-native services around those systems.

## Timeline

Estimated timeline: 4 to 6 weeks.

1. Package cleanup and reproducible install workflow
2. Demo polish and documentation
3. JSON Schema export path for modeled types
4. Focused test coverage and release notes

## Six-Month Roadmap

**Month 1: Developer preview.** Stabilize the package layout, make the `pixi` workflow reliable, publish the shopping cart demo, and document the supported YANG subset clearly.

**Month 2: Schema export.** Complete JSON Schema export from modeled Mojo types, including ranges, required fields, lists, choices, `must`, `when`, and `leafref` metadata where supported.

**Month 3: LLM tool demo.** Add a small schema-derived function-calling demo that turns an xYang model into an LLM tool schema, validates requests, and rejects invalid tool arguments before application logic runs.

**Month 4: Validator hardening.** Expand regression tests for lists, leaf-lists, defaults, choices/cases, XPath predicates, pattern constraints, and leafref resolution. Document known RFC 7950 gaps.

**Month 5: API cleanup.** Refine the public Mojo API around modeled types, validation errors, generated schemas, and examples so external users can build small services without reading internals.

**Month 6: Integration release.** Publish a tagged release with examples, generated artifacts, and a short guide showing how to use xYang as a semantic contract layer for Mojo services and AI-facing APIs.

## Success Criteria

The grant is successful if a Mojo developer can clone the repository, run the package and demo commands, inspect the generated schema artifacts, and understand how xYang connects compile-time model validation with runtime request validation.

## Repository

`xYang.mojo` is licensed under Apache-2.0 and developed in the open.
