## Command-line entry point for validation and YANG -> JSON Schema conversion.

from std.sys import argv

from xyang.json import yang_module_to_json_schema
from xyang.yang.ast.lexer import AstLexer
from xyang.yang.ast.module import YangModule
from xyang.validator.document import validate_yang_document


def _argv_list() -> List[String]:
    var sp = argv()
    var args = List[String]()
    for i in range(len(sp)):
        args.append(String(sp[i]))
    return args^


def _read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return text^


def _write_text(path: String, text: String) raises:
    with open(path, "w") as f:
        f.write(text)


def _parse_yang_module(yang_text: String) raises -> YangModule:
    var lexer = AstLexer(yang_text.as_bytes())
    var module = YangModule()
    module.parse(lexer)
    return module^


def _print_usage():
    var usage = String()
    usage += "usage:\n"
    usage += "  xyang validate <model.yang> <data.json>\n"
    usage += "  xyang schema <model.yang> [-o <schema.yang.json>]\n\n"
    usage += "commands:\n"
    usage += "  validate         Validate a JSON file against a YANG model\n"
    usage += "  schema, convert  Convert a YANG model to JSON Schema with x-yang annotations"
    print(usage)


def _cmd_validate(read args: List[String], start: Int) raises -> Int:
    if len(args) != start + 2:
        print("error: validate requires <model.yang> <data.json>")
        _print_usage()
        return 1
    var yang_path = args[start]
    var data_path = args[start + 1]
    var yang_text = _read_text(yang_path)
    var json_text = _read_text(data_path)
    validate_yang_document(yang_text, json_text, yang_path, data_path)

    var module = _parse_yang_module(yang_text)
    print("YANG module: " + module.get_name())
    print("Data file: " + data_path)
    print("Validation: valid")
    return 0


def _cmd_schema(read args: List[String], start: Int) raises -> Int:
    if start >= len(args):
        print("error: schema requires <model.yang>")
        _print_usage()
        return 1
    var yang_path = args[start]
    var out_path = Optional[String]()
    var i = start + 1
    while i < len(args):
        var a = args[i]
        if a == "-o" or a == "--output":
            i += 1
            if i >= len(args):
                print("error: " + a + " requires a path")
                return 1
            out_path = Optional[String](args[i])
            i += 1
        else:
            print("error: unexpected argument: " + a)
            _print_usage()
            return 1

    var yang_text = _read_text(yang_path)
    var module = _parse_yang_module(yang_text)
    var schema_text = yang_module_to_json_schema(module)
    if out_path:
        _write_text(out_path.value(), schema_text)
        print("Wrote " + out_path.value())
    else:
        print(schema_text)
    return 0


def main() raises:
    var args = _argv_list()
    if len(args) < 2:
        _print_usage()
        return
    var cmd = args[1]
    if cmd == "-h" or cmd == "--help":
        _print_usage()
        return

    var code: Int
    if cmd == "validate":
        code = _cmd_validate(args, 2)
    elif cmd == "schema" or cmd == "convert":
        code = _cmd_schema(args, 2)
    else:
        print("error: unknown command: " + cmd)
        _print_usage()
        code = 1

    if code != 0:
        raise Error("command failed with exit code " + String(code))
