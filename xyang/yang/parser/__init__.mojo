from xyang.ast import YangModule
from xyang.yang.parser.parser import _YangParser


def parse_yang_string(source: String) raises -> YangModule:
    var parser = _YangParser(source)
    return parser.parse_module()


def parse_yang_file(path: String) raises -> YangModule:
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return parse_yang_string(text)
