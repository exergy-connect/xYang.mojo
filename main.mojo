from xyang.json.parser import parse_yang_module


def main():
    # Load JSON meta-model from examples file using Python-style file I/O.
    var text: String
    with open("examples/meta-model.yang.json", "r") as f:
        text = f.read()

    var module = parse_yang_module(text)
    print(module.name, module.namespace, module.prefix)

