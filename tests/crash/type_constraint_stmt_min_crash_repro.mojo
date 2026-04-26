## Standalone minimal crash reproducer for parse_type_statement_impl pattern.
##
## Run:
##   pixi run mojo -I . tests/crash/type_constraint_stmt_min_crash_repro.mojo
##
## To reproduce the crash, uncomment the return line inside
## `parse_type_statement_impl` and comment the fallback return.

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
    # Uncomment this line to reproduce the compiler crash:
    out_type = parser._parse_yang_type(type_name)
    #out_type = YangType(name=type_name)


struct DummyParser(ParserContract):
    var _builtin_type_parsers: Dict[
        String, fn (mut DummyParser, String, out YangType) raises
    ]

    def __init__(out self):
        self._builtin_type_parsers = (
            Dict[String, fn (mut DummyParser, String, out YangType) raises]()
        )
        self._builtin_type_parsers["string"] = _builtin_type_parse_string

    def _consume_name(mut self) raises -> String:
        return "string"

    def _parse_yang_type(
        mut self, read type_name: String, out out_type: YangType
    ) raises:
        var f = self._builtin_type_parsers.get(type_name)
        var t = String(type_name)
        if f:
            return f.value()(self, t^)
        out_type = YangType(name=t^)


def _builtin_type_parse_string(
    mut parser: DummyParser, n: String, out out_type: YangType
) raises:
    _ = parser
    out_type = YangType(name=n)


def main() raises:
    var parser = DummyParser()
    _ = parse_type_statement_impl(parser)
