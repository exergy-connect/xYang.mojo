from xyang.ast import YangModule
from xyang.yang.parser.parser import _YangParser
from xyang.yang.parser.tokenizer import tokenize_yang_impl
from xyang.yang.parser.types import YangToken


def parse_yang_string(source: String) raises -> YangModule:
    var parser = _YangParser(source)
    return parser.parse_module()


def parse_yang_file(path: String) raises -> YangModule:
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return parse_yang_string(text)


def tokenize_yang(source: String) -> List[YangToken]:
    return tokenize_yang_impl(source)
