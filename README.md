# xYang.mojo

Experimental Mojo port of the **xYang** YANG/JSON schema tooling.

The goal of this repository is to:

- model the xYang YANG meta‑model in Mojo, and
- provide a JSON/YANG parser that can load `.yang.json` (hybrid JSON Schema + x-yang)
  into a Mojo AST,
- using [EmberJson](https://github.com/bgreni/EmberJson) as the JSON engine.

> Status: **very early / experimental** – only the JSON/YANG path is sketched out.

## Layout

Planned layout (work in progress):

- `xyang/`
  - `ast.mojo` – core YANG AST types (`YangModule`, containers, lists, leaves, types).
  - `json_parser.mojo` – `parse_json_schema` implemented with EmberJson.

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

