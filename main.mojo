## Same flow as `examples/basic_yang/validator.mojo`: validate YANG + JSON instance.

from xyang.yang.ast.lexer import AstLexer
from xyang.yang.ast.module import YangModule
from xyang.validator.document import validate_yang_document


comptime YANG_PATH = "examples/basic_yang/basic-device.yang"
comptime DATA_PATH = "examples/basic_yang/basic-device.json"


def main() raises:
    var yang_text: String
    with open(YANG_PATH, "r") as f:
        yang_text = f.read()
    var json_text: String
    with open(DATA_PATH, "r") as f:
        json_text = f.read()

    validate_yang_document(
        yang_text, json_text, String(YANG_PATH), String(DATA_PATH)
    )

    var lexer = AstLexer(yang_text.as_bytes())
    var yang_index = YangModule()
    yang_index.parse(lexer)
    print("YANG module: " + yang_index.get_name())
    print("Data file: " + String(DATA_PATH))
    print("Validation: valid")
