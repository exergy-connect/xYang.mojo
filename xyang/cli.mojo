## Command-line interface (mirrors Python `xyang`: parse, validate, convert).

from emberjson import parse as parse_json, Value
from std.sys import argv

from xyang.yang import parse_yang_file
from xyang.json.generator import schema_to_yang_json
from xyang.validator import YangValidator

comptime XYANG_VERSION = "0.1.1"


def _eprint(msg: String) raises:
    ## Use stdout so messages show in environments without a usable `/dev/stderr`.
    print(msg)


def _argv_list() raises -> List[String]:
    var sp = argv()
    var lst = List[String]()
    for i in range(len(sp)):
        lst.append(String(sp[i]))
    return lst^


def _force_yang_json_suffix(path: String) -> String:
    if path.endswith(".yang.json"):
        return path
    var parts = path.split(".")
    if len(parts) < 2:
        return path + ".yang.json"
    var stem = String(parts[0])
    for j in range(1, len(parts) - 1):
        stem = stem + "." + String(parts[j])
    return stem + ".yang.json"


def _default_convert_output(yang_file: String) -> String:
    if yang_file.endswith(".yang"):
        return yang_file + ".json"
    return _force_yang_json_suffix(yang_file)


def _print_help() raises:
    print(
        "usage: xyang [-h] [-V] <command> ...\n\n"
        "xYang: YANG parsing and validation.\n\n"
        "optional arguments:\n"
        "  -h, --help     show this help message and exit\n"
        "  -V, --version  print version and exit\n\n"
        "commands:\n"
        "  parse <yang_file>\n"
        "                  Parse a YANG file and print module info\n"
        "  validate <yang_file> [data_file]\n"
        "                  Validate JSON data against a YANG module\n"
        "                  (read JSON from stdin if data_file is omitted)\n"
        "                  [--anydata-validation {off,complete,candidate}]\n"
        "                  [--anydata-module PATH]...\n"
        "  convert <yang_file> [-o PATH] [--output PATH]\n"
        "                  Convert .yang to .yang.json (JSON Schema with x-yang)\n",
    )


def _cmd_parse(read args: List[String], mut i: Int) raises -> Int:
    if i >= len(args):
        _eprint("Error: parse requires yang_file")
        return 1
    var path = args[i]
    i += 1
    if i < len(args):
        _eprint("Error: unexpected extra arguments after yang_file")
        return 1
    try:
        var yang_module = parse_yang_file(path)
        print("Module: " + yang_module.name)
        print("  yang-version: 1.1")
        print("  namespace: " + yang_module.namespace)
        print("  prefix: " + yang_module.prefix)
        if len(yang_module.organization) > 0:
            print("  organization: " + yang_module.organization)
        print("  typedefs: 0")
        print(
            "  top-level statements: "
            + String(len(yang_module.top_level_containers)),
        )
    except e:
        _eprint("Error: " + String(e))
        return 1
    return 0


def _load_instance_json(path: String) raises -> String:
    if path.endswith(".yaml") or path.endswith(".yml"):
        raise Error(
            "Reading .yaml or .yml requires a YAML library; use JSON for xYang.mojo.",
        )
    with open(path, "r") as f:
        return f.read()


def _cmd_validate(read args: List[String], mut i: Int) raises -> Int:
    if i >= len(args):
        _eprint("Error: validate requires yang_file")
        return 1
    var yang_path = args[i]
    i += 1
    var data_path = Optional[String]()
    var anydata_mode = "off"
    var anydata_modules = List[String]()
    while i < len(args):
        var a = args[i]
        if a == "--anydata-validation":
            i += 1
            if i >= len(args):
                _eprint("Error: --anydata-validation requires a value")
                return 1
            anydata_mode = args[i]
            i += 1
        elif a == "--anydata-module":
            i += 1
            if i >= len(args):
                _eprint("Error: --anydata-module requires PATH")
                return 1
            anydata_modules.append(args[i])
            i += 1
        elif a.startswith("-"):
            _eprint("Error: unknown option: " + a)
            return 1
        else:
            if data_path:
                _eprint("Error: unexpected extra positional argument: " + a)
                return 1
            data_path = Optional(a)
            i += 1

    if anydata_mode != "off":
        _eprint(
            "Error: --anydata-validation is not implemented in xYang.mojo (use off).",
        )
        return 1
    if len(anydata_modules) > 0:
        _eprint(
            "Error: --anydata-module is not implemented in xYang.mojo.",
        )
        return 1

    try:
        var yang_module = parse_yang_file(yang_path)

        var json_text: String
        if data_path:
            json_text = _load_instance_json(data_path.value())
        else:
            with open("/dev/stdin", "r") as f:
                json_text = f.read()

        var data = parse_json(json_text)
        var validator = YangValidator()
        var result = validator.validate(data, yang_module)
        if result.is_valid:
            print("Valid.")
            for j in range(len(result.warnings)):
                print("  Warning: " + result.warnings[j])
            return 0
        _eprint("Validation failed:")
        for j in range(len(result.errors)):
            _eprint("  " + result.errors[j])
        return 1
    except e:
        _eprint("Error: " + String(e))
        return 1


def _cmd_convert(read args: List[String], mut i: Int) raises -> Int:
    if i >= len(args):
        _eprint("Error: convert requires yang_file")
        return 1
    var yang_path = args[i]
    i += 1
    var out_opt = Optional[String]()
    while i < len(args):
        var a = args[i]
        if a == "-o" or a == "--output":
            i += 1
            if i >= len(args):
                _eprint("Error: " + a + " requires a path")
                return 1
            out_opt = Optional(args[i])
            i += 1
        else:
            _eprint("Error: unexpected argument: " + a)
            return 1

    var out_path: String
    if out_opt:
        out_path = _force_yang_json_suffix(out_opt.value())
    else:
        out_path = _default_convert_output(yang_path)

    try:
        var yang_module = parse_yang_file(yang_path)
        var text = schema_to_yang_json(yang_module)
        with open(out_path, "w") as f:
            f.write(text)
        print("Wrote " + out_path)
    except e:
        _eprint("Error: " + String(e))
        return 1
    return 0


def run_cli() raises -> Int:
    var args = _argv_list()
    if len(args) < 2:
        _print_help()
        return 0
    var i = 1
    if args[i] == "-h" or args[i] == "--help":
        _print_help()
        return 0
    if args[i] == "-V" or args[i] == "--version":
        print("xyang " + XYANG_VERSION)
        return 0

    var cmd = args[i]
    i += 1
    if cmd == "parse":
        return _cmd_parse(args, i)
    if cmd == "validate":
        return _cmd_validate(args, i)
    if cmd == "convert":
        return _cmd_convert(args, i)

    _eprint("Error: unknown command: " + cmd)
    _print_help()
    return 1
