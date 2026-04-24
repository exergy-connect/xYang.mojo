# xYang.mojo

Experimental Mojo port of the **xYang** YANG/JSON schema tooling.

The goal of this repository is to:

- model the xYang YANG meta‑model in Mojo, and
- provide a JSON/YANG parser that can load `.yang.json` (hybrid JSON Schema + x-yang)
  into a Mojo AST,
- using [EmberJson](https://github.com/bgreni/EmberJson) as the JSON engine.

> Status: **very early / experimental** – only the JSON/YANG path is sketched out.

## Building the `xyang` library (`.mojopkg`)

The `xyang` package is compiled into a portable [Mojo package](https://docs.modular.com/mojo/manual/packages) (`xyang.mojopkg`). The build depends on **EmberJson** on the Mojo import path (this repo’s Pixi environment provides `emberjson.mojopkg` under `lib/mojo`).

```bash
# From the repo root (after `pixi install`)
pixi run package
# Produces: build/xyang.mojopkg

# Optional: link against the artifact + EmberJson
pixi run verify-package
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

1. Build the package: `pixi run package` (creates `build/xyang.mojopkg`).
2. Run a test with **`xyang` from `build/` only** (no `-I .`), and EmberJson on the path:

   ```bash
   pixi run mojo -I build -I .pixi/envs/default/lib/mojo tests/xpath/test_evaluator.mojo
   ```

3. **Working directory:** run from the **repository root** so tests that open files (for example `examples/basic_yang/basic-device.yang`) resolve paths the same as with source-based runs.

4. **Tests that are not covered by the library alone:** the alternate XPath tests live in `alternatives/test_alt_parser.mojo` (next to the `alternatives` package). Run with `-I .` from the repo root, e.g. `mojo -I . alternatives/test_alt_parser.mojo`. Everything that only imports `xyang` and `emberjson` can use the two `-I` lines above.

Convenience: `pixi run tests-mojopkg` runs the main integration tests against `build/xyang.mojopkg` (skips `alternatives/test_alt_parser.mojo`, which is not in the `xyang` package).

## Layout

- `xyang/`
  - `ast.mojo` – YANG AST types (`YangModule`, containers, lists, leaves, types, …)
  - `json/` – JSON Schema + x-yang parsing; JSON Schema generation
  - `yang/` – text YANG parser
  - `validator/` – document validation, leafref, `must` / `when`, …
  - `xpath/` – tokenizer, Pratt parser, evaluator for constraint XPath
- `packaging/verify_mojopkg.mojo` – smoke import for `pixi run verify-package`
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

