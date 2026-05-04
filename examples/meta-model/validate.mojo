## Validate a JSON data-model instance against the meta-model schema.
##
## The schema is loaded from `meta-model.yang.json` (JSON Schema + `x-yang`),
## which is the same module as `meta-model.yang` in this repository. The
## text `.yang` file uses constructs (for example `choice` inside `grouping`)
## that are not yet accepted by the shared YANG text parser/spec table.
##
## From the repository root (with `xyang` on the import path):
##
##   pixi run mojo -I . examples/meta-model/validate.mojo examples/meta-model/model/simple.json

from std.sys import argv

from xyang.json import parse_yang_json_module
from xyang.json.parser import parse_json
from xyang.validator.document import validate_data


comptime META_MODEL_SCHEMA_PATH = "examples/meta-model/meta-model.yang.json"


def main() raises:
    var sp = argv()
    if len(sp) < 2:
        raise Error(
            "usage: mojo -I . examples/meta-model/validate.mojo <instance.json>"
        )
    var instance_path = String(sp[1])

    var schema_text: String
    with open(String(META_MODEL_SCHEMA_PATH), "r") as sf:
        schema_text = sf.read()

    var instance_text: String
    with open(instance_path, "r") as jf:
        instance_text = jf.read()

    var module = parse_yang_json_module(
        schema_text, String(META_MODEL_SCHEMA_PATH)
    )
    var data = parse_json(instance_text, instance_path)
    validate_data(data, module, instance_path)

    print("Schema: " + String(META_MODEL_SCHEMA_PATH))
    print("Instance: " + instance_path)
    print("Validation: valid")
