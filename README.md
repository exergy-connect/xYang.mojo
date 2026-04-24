# xYang.mojo

Experimental Mojo port of the **xYang** YANG/JSON schema tooling.

The goal of this repository is to:

- model the xYang YANG meta‑model in Mojo, and
- provide a JSON/YANG parser that can load `.yang.json` (hybrid JSON Schema + x-yang)
  into a Mojo AST,
- using [EmberJson](https://github.com/bgreni/EmberJson) as the JSON engine.

> Status: **very early / experimental** – only the JSON/YANG path is sketched out.

## Fast workflow: precompiled `xyang.mojopkg`

After you change code under `xyang/`, rebuild the package, then use **`compile-check`** (or any single `mojo` invocation with **`-I build`**) so the compiler links against the **prebuilt** `build/xyang.mojopkg` plus EmberJson — much faster than re-running the full test suite from source with `-I .` on every check.

```bash
pixi run package          # produces build/xyang.mojopkg
pixi run compile-check    # one small test file against the mojopkg
```

Use `pixi run tests-mojopkg` or `pixi run tests` only when you need a full regression (slower). Day-to-day: `package` + `compile-check` or a targeted `mojo -I build -I .pixi/envs/default/lib/mojo <file>.mojo` from the repo root.

## Building the `xyang` library (`.mojopkg`)

The `xyang` package is compiled into a portable [Mojo package](https://docs.modular.com/mojo/manual/packages) (`xyang.mojopkg`). The build depends on **EmberJson** on the Mojo import path (this repo’s Pixi environment provides `emberjson.mojopkg` under `lib/mojo`).

```bash
# From the repo root (after `pixi install`)
pixi run package
# Produces: build/xyang.mojopkg
```

Manual equivalent:

```bash
mkdir -p build
export MODULAR_MOJO_IMPORT_PATH="$PWD/.pixi/envs/default/lib/mojo"
mojo package -I. -o build/xyang.mojopkg xyang
```

**Consuming the library:** pass **both** the directory containing `xyang.mojopkg` and the directory containing `emberjson.mojopkg` to the compiler, for example:

```bash
mojo build -I build -I "$CONDA_PREFIX/lib/mojo" myapp.mojo
```

Alternatively, set `MODULAR_MOJO_IMPORT_PATH` to a `:`-separated list of those directories. Then:

```mojo
from xyang import parse_json_schema, parse_yang_file
```

Subpackages (`xyang.json`, `xyang.validator`, `xyang.xpath`, …) work like imports from source with `-I.`.

### Running tests against the compiled `xyang.mojopkg`

1. `pixi run package` (creates `build/xyang.mojopkg`) — required after you change `xyang/` before mojopkg-based runs.
2. `pixi run compile-check` — single fast check against the prebuilt package.
3. For more coverage without compiling all of `xyang` from source: `pixi run tests-mojopkg` (still slower than one file; for broad regression).
4. **Working directory:** run from the **repository root** for tests that open `examples/...` paths.
5. **`alternatives/test_alt_parser.mojo`** needs the `alternatives` package: `mojo -I . alternatives/test_alt_parser.mojo` (not in the `xyang` mojopkg).

## Layout

- `xyang/`
  - `ast.mojo` – YANG AST types (`YangModule`, containers, lists, leaves, types, …)
  - `json/` – JSON Schema + x-yang parsing; JSON Schema generation
  - `yang/` – text YANG parser
  - `validator/` – document validation, leafref, `must` / `when`, …
  - `xpath/` – tokenizer, Pratt parser, evaluator for constraint XPath
- `main.mojo` – CLI (`pixi run xyang -- …`)

## Using EmberJson

This project assumes EmberJson is available in your Mojo toolchain. See the
EmberJson repository for installation instructions and examples:

- GitHub: [bgreni/EmberJson](https://github.com/bgreni/EmberJson)

Example of using EmberJson in Mojo:

```mojo
from emberjson import parse, Value

fn main() raises:
    let doc: Value = parse(r#"{"key": 123}"#)
    let obj = doc.object()
    print(obj["key"].int())
```

The xYang.mojo JSON/YANG parser will build on this to walk the parsed `Value`
tree and construct a `YangModule` AST.

