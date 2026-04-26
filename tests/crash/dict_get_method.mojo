## Standalone minimal crash reproducer for parse_type_statement_impl pattern.
##
## Run:
##   pixi run mojo -I . tests/crash/dict_get_method.mojo
##

from std.collections import Dict
from std.sys import stderr

struct YangType:
    var name: String

    def __init__(out self, name: String):
        self.name = name


trait ParserContract:
    def _consume_name(mut self) raises -> String:
        ...

    def _parse_yang_type(
        mut self, read type_name: String, out out_type: YangType
    ) raises:
        ...


def parse_type_statement_impl[ParserT: ParserContract](
    mut parser: ParserT, out out_type: YangType
) raises:
    ref type_name = parser._consume_name()
    print("[debug] parse_type_statement_impl: type_name=", type_name, file=stderr)
    out_type = parser._parse_yang_type(type_name)


struct DummyParser(ParserContract):
    var _builtin_type_parsers: Dict[
        String, fn (mut DummyParser, String) raises -> YangType
    ]

    def __init__(out self):
        self._builtin_type_parsers = (
            Dict[String, fn (mut DummyParser, String) raises -> YangType]()
        )
        self._builtin_type_parsers["string"] = _builtin_type_parse_string

    def _consume_name(mut self) raises -> String:
        return "string"

    def _parse_yang_type(
        mut self, read type_name: String, out out_type: YangType
    ) raises:
        # Uncomment these 3 lines to reproduce the compiler crash:
        # var f = self._builtin_type_parsers.get(type_name)
        # if f:
        #     return f.value()(self, type_name)

        # Workaround: Don't use get()
        if type_name in self._builtin_type_parsers:
            out_type = self._builtin_type_parsers[type_name](self, type_name)
        else:
            out_type = YangType(name="?")


fn _builtin_type_parse_string(mut parser: DummyParser, n: String) raises -> YangType:
    _ = parser
    return YangType(name=n)


def main() raises:
    var parser = DummyParser()
    _ = parse_type_statement_impl(parser)
