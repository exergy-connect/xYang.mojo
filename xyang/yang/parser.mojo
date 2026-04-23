## Text YANG parser for Mojo AST (modeled after Python xYang parser flow).
##
## Supported subset:
## - module header: module, namespace, prefix, description, revision
## - data nodes: container, list, leaf, choice/case
## - leaf/list details: type, mandatory, key
## - must on leaves with optional error-message/description block

from std.collections.string import Codepoint
from std.memory import ArcPointer
from xyang.ast import (
    YangModule,
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangType,
    YangMust,
    YangWhen,
    YangStatementWithMust,
    YangStatementWithWhen,
)
from xyang.xpath import parse_xpath, Expr

comptime Arc = ArcPointer
comptime CP_NEWLINE = Codepoint.ord("\n")
comptime CP_SLASH = Codepoint.ord("/")
comptime CP_STAR = Codepoint.ord("*")
comptime CP_DQUOTE = Codepoint.ord('"')
comptime CP_SQUOTE = Codepoint.ord("'")
comptime CP_BACKSLASH = Codepoint.ord("\\")
comptime CP_BRACE_OPEN = Codepoint.ord("{")
comptime CP_BRACE_CLOSE = Codepoint.ord("}")
comptime CP_SEMICOLON = Codepoint.ord(";")
comptime CP_COLON = Codepoint.ord(":")
comptime CP_PLUS = Codepoint.ord("+")


def _empty_when_statement() -> YangStatementWithWhen:
    return YangStatementWithWhen(
        has_when = False,
        when_statement = YangWhen(
            expression = "",
            description = "",
            xpath_ast = Expr.ExprPointer(),
            parsed = False,
        ),
    )


@fieldwise_init
struct YangToken(Copyable, Movable):
    var value: String
    var quoted: Bool
    var line: Int
    var col: Int


struct _YangParser(Movable):
    var tokens: List[YangToken]
    var index: Int

    def __init__(out self, var tokens: List[YangToken]):
        self.tokens = tokens^
        self.index = 0

    def parse_module(mut self) raises -> YangModule:
        self._expect("module")
        var module_name = self._consume_name()
        self._expect("{")

        var namespace = ""
        var prefix = ""
        var top_containers = List[Arc[YangContainer]]()

        while self._has_more() and self._peek() != "}":
            var stmt = self._peek()
            if stmt == "namespace":
                self._consume()
                namespace = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == "prefix":
                self._consume()
                prefix = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == "description":
                self._consume()
                _ = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == "revision":
                self._consume()
                _ = self._consume_argument_value()
                if self._consume_if("{"):
                    self._skip_block_body()
                self._skip_if(";")
            elif stmt == "container":
                var c = self._parse_container_statement()
                top_containers.append(Arc[YangContainer](c^))
            else:
                self._skip_statement()

        self._expect("}")
        self._skip_if(";")

        return YangModule(
            name = module_name,
            namespace = namespace,
            prefix = prefix,
            top_level_containers = top_containers^,
        )

    def _parse_container_statement(mut self) raises -> YangContainer:
        self._expect("container")
        var name = self._consume_name()

        var desc = ""
        var leaves = List[Arc[YangLeaf]]()
        var containers = List[Arc[YangContainer]]()
        var lists = List[Arc[YangList]]()
        var choices = List[Arc[YangChoice]]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "description":
                    self._consume()
                    desc = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == "leaf":
                    var leaf = self._parse_leaf_statement()
                    leaves.append(Arc[YangLeaf](leaf^))
                elif stmt == "container":
                    var child_container = self._parse_container_statement()
                    containers.append(Arc[YangContainer](child_container^))
                elif stmt == "list":
                    var child_list = self._parse_list_statement()
                    lists.append(Arc[YangList](child_list^))
                elif stmt == "choice":
                    var choice = self._parse_choice_statement()
                    choices.append(Arc[YangChoice](choice^))
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangContainer(
            name = name,
            description = desc,
            leaves = leaves^,
            containers = containers^,
            lists = lists^,
            choices = choices^,
        )

    def _parse_list_statement(mut self) raises -> YangList:
        self._expect("list")
        var name = self._consume_name()

        var key = ""
        var desc = ""
        var leaves = List[Arc[YangLeaf]]()
        var containers = List[Arc[YangContainer]]()
        var lists = List[Arc[YangList]]()
        var choices = List[Arc[YangChoice]]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "key":
                    self._consume()
                    key = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == "description":
                    self._consume()
                    desc = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == "leaf":
                    var leaf = self._parse_leaf_statement()
                    leaves.append(Arc[YangLeaf](leaf^))
                elif stmt == "container":
                    var child_container = self._parse_container_statement()
                    containers.append(Arc[YangContainer](child_container^))
                elif stmt == "list":
                    var child_list = self._parse_list_statement()
                    lists.append(Arc[YangList](child_list^))
                elif stmt == "choice":
                    var choice = self._parse_choice_statement()
                    choices.append(Arc[YangChoice](choice^))
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangList(
            name = name,
            key = key,
            description = desc,
            leaves = leaves^,
            containers = containers^,
            lists = lists^,
            choices = choices^,
        )

    def _parse_leaf_statement(mut self) raises -> YangLeaf:
        self._expect("leaf")
        var name = self._consume_name()

        var type_stmt = YangType(
            name = "unknown",
            has_range = False,
            range_min = 0,
            range_max = 0,
        )
        var mandatory = False
        var must = List[Arc[YangMust]]()
        var with_when = _empty_when_statement()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "type":
                    type_stmt = self._parse_type_statement()
                elif stmt == "mandatory":
                    self._consume()
                    mandatory = self._parse_boolean_value()
                    self._skip_if(";")
                elif stmt == "must":
                    var m = self._parse_must_statement()
                    must.append(Arc[YangMust](m^))
                elif stmt == "when":
                    var w = self._parse_when_statement()
                    with_when = YangStatementWithWhen(has_when=True, when_statement=w^)
                elif stmt == "description":
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangLeaf(
            name = name,
            type = type_stmt^,
            mandatory = mandatory,
            with_must = YangStatementWithMust(must_statements = must^),
            with_when = with_when^,
        )

    def _parse_choice_statement(mut self) raises -> YangChoice:
        self._expect("choice")
        var name = self._consume_name()

        var mandatory = False
        var case_names = List[String]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "mandatory":
                    self._consume()
                    mandatory = self._parse_boolean_value()
                    self._skip_if(";")
                elif stmt == "case":
                    var names = self._parse_case_statement()
                    for i in range(len(names)):
                        case_names.append(names[i])
                elif stmt == "leaf":
                    self._consume()
                    case_names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == "container":
                    self._consume()
                    case_names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == "list":
                    self._consume()
                    case_names.append(self._consume_name())
                    self._skip_statement_tail()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangChoice(
            name = name,
            mandatory = mandatory,
            case_names = case_names^,
        )

    def _parse_case_statement(mut self) raises -> List[String]:
        self._expect("case")
        _ = self._consume_name()

        var names = List[String]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "leaf":
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == "container":
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == "list":
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return names^

    def _parse_type_statement(mut self) raises -> YangType:
        self._expect("type")
        var type_name = self._consume_name()
        var has_range = False
        var range_min = Int64(0)
        var range_max = Int64(0)

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "range":
                    self._consume()
                    var range_expr = self._consume_argument_value()
                    var parts = range_expr.split("..")
                    if len(parts) == 2:
                        try:
                            range_min = Int64(atol(parts[0].strip()))
                            range_max = Int64(atol(parts[1].strip()))
                            has_range = True
                        except:
                            has_range = False
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangType(
            name = type_name,
            has_range = has_range,
            range_min = range_min,
            range_max = range_max,
        )

    def _parse_must_statement(mut self) raises -> YangMust:
        self._expect("must")
        var expression = self._consume_argument_value()
        var error_message = ""
        var description = ""

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "error-message":
                    self._consume()
                    error_message = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == "description":
                    self._consume()
                    description = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        var xpath_ast = Expr.ExprPointer()
        try:
            xpath_ast = parse_xpath(expression)
            return YangMust(
                expression = expression,
                error_message = error_message,
                description = description,
                xpath_ast = xpath_ast,
                parsed = True,
            )
        except:
            return YangMust(
                expression = expression,
                error_message = error_message,
                description = description,
                xpath_ast = xpath_ast,
                parsed = False,
            )

    def _parse_when_statement(mut self) raises -> YangWhen:
        self._expect("when")
        var expression = self._consume_argument_value()
        var description = ""

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == "description":
                    self._consume()
                    description = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        var xpath_ast = Expr.ExprPointer()
        try:
            xpath_ast = parse_xpath(expression)
            return YangWhen(
                expression = expression,
                description = description,
                xpath_ast = xpath_ast,
                parsed = True,
            )
        except:
            return YangWhen(
                expression = expression,
                description = description,
                xpath_ast = xpath_ast,
                parsed = False,
            )

    def _parse_boolean_value(mut self) raises -> Bool:
        var value = self._consume_value()
        if value == "true":
            return True
        if value == "false":
            return False
        self._error("Expected boolean value 'true' or 'false', got '" + value + "'")
        return False

    def _consume_argument_value(mut self) raises -> String:
        if not self._has_more():
            self._error("Expected argument value, found end of input")
            return ""

        var value = self._consume_value()

        # YANG string concatenation: "a" + "b"
        while self._consume_if("+"):
            value += self._consume_value()

        return value

    def _consume_name(mut self) raises -> String:
        var first = self._consume_value()
        if first == "{" or first == "}" or first == ";":
            self._error("Expected statement argument, got '" + first + "'")
            return ""

        var name = first
        while self._consume_if(":"):
            name += ":"
            name += self._consume_value()
        return name

    def _skip_statement_tail(mut self) raises:
        if self._consume_if(";"):
            return
        if self._consume_if("{"):
            self._skip_block_body()
            self._skip_if(";")
            return
        while self._has_more():
            var v = self._peek()
            if v == ";":
                self._consume()
                return
            if v == "{":
                self._consume()
                self._skip_block_body()
                self._skip_if(";")
                return
            if v == "}":
                return
            self._consume()

    def _skip_statement(mut self) raises:
        self._consume()
        self._skip_statement_tail()

    def _skip_block_body(mut self) raises:
        # Entry point assumes the opening '{' was already consumed.
        var depth = 1
        while self._has_more() and depth > 0:
            var value = self._consume_value()
            if value == "{":
                depth += 1
            elif value == "}":
                depth -= 1

    def _expect(mut self, value: String) raises:
        if not self._has_more():
            self._error("Expected '" + value + "', found end of input")
            return
        var got = self._peek()
        if got != value:
            self._error("Expected '" + value + "', got '" + got + "'")
            return
        self.index += 1

    def _consume_if(mut self, value: String) -> Bool:
        if self._has_more() and self.tokens[self.index].value == value:
            self.index += 1
            return True
        return False

    def _skip_if(mut self, value: String):
        if self._has_more() and self.tokens[self.index].value == value:
            self.index += 1

    def _consume(mut self) raises:
        if not self._has_more():
            self._error("Unexpected end of input")
            return
        _ = self._consume_value()

    def _consume_value(mut self) raises -> String:
        if not self._has_more():
            self._error("Unexpected end of input")
            return ""
        var tok_value = self.tokens[self.index].value.copy()
        self.index += 1
        return tok_value

    def _peek(ref self) -> String:
        return self.tokens[self.index].value

    def _has_more(ref self) -> Bool:
        return self.index < len(self.tokens)

    def _error(ref self, message: String) raises:
        if self._has_more():
            ref tok = self.tokens[self.index]
            raise Error(
                "YANG parse error at line "
                + String(tok.line)
                + ", col "
                + String(tok.col)
                + ": "
                + message,
            )
        raise Error("YANG parse error at end of input: " + message)


def tokenize_yang(source: String) -> List[YangToken]:
    var tokens = List[YangToken]()

    var i = 0
    var n = len(source)
    var line = 1
    var line_start = 0

    while i < n:
        var ch = _codepoint_at_byte(source, i)

        if _is_space(ch):
            if ch == CP_NEWLINE:
                line += 1
                line_start = i + 1
            i += 1
            continue

        if ch == CP_SLASH and i + 1 < n:
            var nxt = _codepoint_at_byte(source, i + 1)
            if nxt == CP_SLASH:
                i += 2
                while i < n and _codepoint_at_byte(source, i) != CP_NEWLINE:
                    i += 1
                continue
            if nxt == CP_STAR:
                i += 2
                while i < n:
                    var c = _codepoint_at_byte(source, i)
                    if i + 1 < n and c == CP_STAR and _codepoint_at_byte(source, i + 1) == CP_SLASH:
                        i += 2
                        break
                    if c == CP_NEWLINE:
                        line += 1
                        line_start = i + 1
                    i += 1
                continue

        if _is_symbol(ch):
            tokens.append(
                YangToken(
                    value=String(source[byte=i : i + 1]),
                    quoted=False,
                    line=line,
                    col=i - line_start,
                ),
            )
            i += 1
            continue

        if ch == CP_DQUOTE or ch == CP_SQUOTE:
            var quote = ch
            var start_col = i - line_start
            i += 1
            var out = ""
            while i < n:
                var c = _codepoint_at_byte(source, i)
                if c == quote:
                    i += 1
                    break
                if c == CP_BACKSLASH and i + 1 < n:
                    out += String(source[byte=i + 1 : i + 2])
                    i += 2
                    continue
                out += String(source[byte=i : i + 1])
                if c == CP_NEWLINE:
                    line += 1
                    line_start = i + 1
                i += 1
            tokens.append(YangToken(value=out, quoted=True, line=line, col=start_col))
            continue

        var start = i
        var col = i - line_start
        while i < n:
            var c = _codepoint_at_byte(source, i)
            if _is_space(c) or _is_symbol(c) or c == CP_DQUOTE or c == CP_SQUOTE:
                break
            if c == CP_SLASH and i + 1 < n:
                var n2 = _codepoint_at_byte(source, i + 1)
                if n2 == CP_SLASH or n2 == CP_STAR:
                    break
            i += 1
        if i > start:
            tokens.append(
                YangToken(
                    value=String(source[byte=start : i]),
                    quoted=False,
                    line=line,
                    col=col,
                ),
            )
            continue

        i += 1

    return tokens^


def _is_space(ch: Codepoint) -> Bool:
    return ch.is_posix_space()


def _is_symbol(ch: Codepoint) -> Bool:
    return (
        ch == CP_BRACE_OPEN
        or ch == CP_BRACE_CLOSE
        or ch == CP_SEMICOLON
        or ch == CP_COLON
        or ch == CP_PLUS
    )


def _codepoint_at_byte(source: String, i: Int) -> Codepoint:
    return Codepoint.ord(source[byte=i : i + 1])


def parse_yang_string(source: String) raises -> YangModule:
    var tokens = tokenize_yang(source)
    var parser = _YangParser(tokens^)
    return parser.parse_module()


def parse_yang_file(path: String) raises -> YangModule:
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return parse_yang_string(text)
