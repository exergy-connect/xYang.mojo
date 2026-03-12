## Smoke test: parse module, parse data, run validator.

from emberjson import parse, Value
from xyang.json.parser import parse_yang_module
from xyang.validator.yang_validator import YangValidator


def main():
    var schema_text: String
    with open("examples/meta-model.yang.json", "r") as f:
        schema_text = f.read()
    var module = parse_yang_module(schema_text)

    var data_json = '{"data-model": {"name": "test", "version": "1.0"}}'
    var data: Value = parse(data_json)

    var validator = YangValidator(module)
    var is_valid = False
    var errors = List[String]()
    var warnings = List[String]()
    is_valid, errors, warnings = validator.validate(data)

    print("Valid:" if is_valid else "Invalid")
    for i in range(len(errors)):
        print("  error: " + errors[i])
