## Load the text YANG module and validate instance data (JSON) against it.
##
## Mojo resolves `xyang` via the module search path. Run from the repository
## root so `-I .` includes the package and relative `open()` paths work:
##   pixi run basic-yang-example
##   # or: pixi run mojo -I. examples/basic_yang/main.mojo

from emberjson import parse as parse_json, Value
from xyang.yang import parse_yang_file
from xyang.validator import YangValidator

comptime YANG_PATH = "examples/basic_yang/basic-device.yang"
comptime DATA_PATH = "examples/basic_yang/basic-device.json"


def main() raises:
    var module = parse_yang_file(YANG_PATH)

    var json_text: String
    with open(DATA_PATH, "r") as f:
        json_text = f.read()
    var data: Value = parse_json(json_text)

    var validator = YangValidator()
    var result = validator.validate(data, module)

    print("YANG module: " + module.name)
    print("Data file: " + DATA_PATH)
    print("Validation: " + ("valid" if result.is_valid else "invalid"))
    for i in range(len(result.errors)):
        print("  error: " + result.errors[i])
    for i in range(len(result.warnings)):
        print("  warning: " + result.warnings[i])
