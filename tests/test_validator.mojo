## Smoke test: parse module, parse data, run validator.

from emberjson import parse, Value
from xyang.json.parser import parse_yang_module
from xyang.validator import YangValidator


def main() raises:
    var schema_text: String
    with open("examples/meta-model.yang.json", "r") as f:
        schema_text = f.read()
    var module = parse_yang_module(schema_text)

    var data_json = '{"data-model": {"name": "test", "version": "1.0"}}'
    var data: Value = parse(data_json)

    var validator = YangValidator()
    var result = validator.validate(data, module)

    print("Valid:" if result.is_valid else "Invalid")
    for i in range(len(result.errors)):
        print("  error: " + result.errors[i])
