## Using `deserialize` for the YANG meta‑model

This project experimented with using EmberJson’s reflection‑based `deserialize[T]` to parse the JSON/YANG meta‑model directly into typed Mojo structs. The goal was:

- Define schema structs (`YangJsonSchemaRoot`, `JsonSchema`, `XYangModuleInfo`, `XYangProperty`) that mirror `examples/meta-model.yang.json`.
- Call `deserialize[YangJsonSchemaRoot](json)` and then convert that into the existing AST (`YangModule`, `YangContainer`, …).
- Eventually, also support `deserialize[YangModule](json)` for a “direct AST JSON” format.

### What worked

- **Direct AST deserialization**: in isolation, `deserialize[YangModule](json)` works fine when the JSON object *exactly* matches the `YangModule` fields (no extra keys).
- **Minimal Optional usage**: when structs only contain plain fields (`String`, `Bool`, `List[...]`, etc.), reflection works as expected and surfaces good “Missing key: …” / “Unexpected field: …” errors.

### What failed

Two hard blockers showed up when trying to apply `deserialize` to the real meta‑model.

#### 1. Structs with `Value` fields

The JSON Schema meta‑model has recursive parts like `properties`, `items`, `oneOf`, `$defs`. A naive design was:

- `properties: Value`
- `items: Value`
- `oneOf: Value`
- `$defs: Value`

and similar in the root:

- `properties: Value`
- `$defs: Value`

With this shape, `deserialize[T]` where `T` has a `Value` field fails in EmberJson’s reflection layer with a compile‑time error chain that ends in:

> `cannot reference parametric function`

This is reproducible with a *minimal* example (see `issues/reflection-deserialization-value.mojo`):

```mojo
from emberjson import deserialize, JsonDeserializable, Value

@fieldwise_init
struct ValueWrapper(Movable, JsonDeserializable):
    var properties: Value

def main():
    var json = "{\"properties\": {}}"
    var wrapper = deserialize[ValueWrapper](json)  # triggers reflection error
    print(wrapper.properties.is_object())
```

Reflection tries to instantiate the generic deserializer for `ValueWrapper` and hits an internal limitation when a struct field itself is a reflective JSON “sum type” (`Value`), resulting in the parametric‑function error instead of a normal user‑level message.

#### 2. Strict field matching and `$schema` / extra keys

Reflection‑based `deserialize[T]` is **strict**:

- Every JSON object key must correspond to a field in `T`.
- Extra keys cause an error like:

  > `Unexpected field: $schema`

This is the expected behavior in the small repro (`issues/reflection-deserialization-$schema.mojo`), where `SchemaWrapper` has only `name` but the JSON also has `"$schema"`.

However, it also means:

- You **cannot** safely point `deserialize[YangModule]` at `examples/meta-model.yang.json`:
  - The root JSON has `"$schema"`, `"description"`, `"x-yang"`, `"type"`, `"properties"`, `$defs`, etc.
  - `YangModule` has only `name/namespace/prefix/top_level_containers`.
  - Reflection stops at the first extra key (`$schema`) with `Unexpected field: $schema`.

For the meta‑model use case, that strictness is undesirable — the JSON Schema root necessarily has many more fields than the target AST.

### Why we rolled it back

Given the current Mojo/EmberJson version (Mojo 0.26.1.0) the combination of:

- Reflection limits around structs containing `Value`, and
- Strict “no extra keys” semantics for `deserialize[T]`

made the `schema.mojo` + `deserialize[YangJsonSchemaRoot]` approach too fragile:

- The meta‑model JSON schema is large, recursive, and contains many extension keys.
- Getting a fully typed, reflection‑friendly struct graph that both:
  - avoids `Value`, and
  - tolerates extra keys
  would require non‑trivial changes to EmberJson itself.

For now, the project has reverted to:

- **Manual parsing** using `emberjson.parse` + `Value` in `xyang/json/parser.mojo` (`parse_yang_module`).
- Keeping `schema.mojo` and the issue repros under `issues/` as documentation of the attempted design and the current EmberJson limitations.

### Guidance for AI tools

These experiments also surfaced a pattern that is *tempting* for AI assistants but wrong for this codebase:

- **Do not “paper over” schema structure with `Value` fields.**
  - Using `Value` (raw JSON) as a field type inside reflection‑deserializable structs is **wrong in principle** – it throws away known structure and static type information, defeats the entire purpose of reflection, and produces brittle, unmaintainable designs. This is not an opinionated local style; it is a design error in any EmberJson‑based codebase.
  - It hides structure the meta‑model already has, and it actively fights EmberJson’s reflection and Mojo’s type system.
  - In this project, any future use of `Value` should be **local and manual** (e.g. ad‑hoc parsing in one function), not baked into the schema layer.

If an assistant is trying to “fix” reflection errors by:

- Adding `Value` fields to schema structs, or
- Wrapping recursive structures in `Value` instead of modeling them with proper types (`Dict`, `List`, `Arc[...]`),

that is a red flag. The right fix is to:

- Model the JSON/YANG meta‑model with explicit, typed fields (even if that means a bit more boilerplate), or
- Fall back to the existing manual `Value`‑based parser (`parse_yang_module`) rather than mixing reflection and `Value`.
