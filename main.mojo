from emberjson import parse as parse_json, Value
from xyang.json.parser import parse_yang_module
from xyang.utils import print_module_tree
from xyang.validator import YangValidator


def main():
    # Load JSON meta-model from examples file using Python-style file I/O.
    var text: String
    with open("examples/meta-model.yang.json", "r") as f:
        text = f.read()

    var module = parse_yang_module(text)
    print_module_tree(module)

    # Validate a minimal data document
    var data_json = '{"data-model": {"name": "test", "version": "1.0"}}'
    var data: Value = parse_json(data_json)
    var validator = YangValidator()
    try:
        var result = validator.validate(data, module)
        print("Validation: " + ("valid" if result.is_valid else "invalid"))
        for i in range(len(result.errors)):
            print("  " + result.errors[i])
    except e:
        print("Validation error: " + String(e))

