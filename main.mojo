from xyang.json.parser import parse_yang_module
from xyang.utils import print_module_tree


def main():
    # Load JSON meta-model from examples file using Python-style file I/O.
    var text: String
    with open("examples/meta-model.yang.json", "r") as f:
        text = f.read()

    var module = parse_yang_module(text)
    print_module_tree(module)

