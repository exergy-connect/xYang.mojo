from std.collections import List
from std.memory import ArcPointer, Span
from std.utils import Variant
from xyang.yang.xpath.token import Token
from xyang.yang.xpath.tokenizer import XPathTokenizer

comptime Arc = ArcPointer
comptime ByteView = Span[Byte, _]

# -----------------------------
# AST payload nodes (Variant members)
# -----------------------------


@fieldwise_init
struct XPathAtom(Movable):
    """Leaf expression: number, string, or name; semantics come from `XPathExpr.value`.
    """

    pass


@fieldwise_init
struct XPathBinaryOp(Movable):
    """Infix operator: operator token lives on the enclosing `XPathExpr.value`.
    """

    var left: Arc[XPathExpr]
    var right: Arc[XPathExpr]


@fieldwise_init
struct XPathCall(Movable):
    """Function call: callee name token is `XPathExpr.value`."""

    var args: List[Arc[XPathExpr]]


@fieldwise_init
struct XPathPath(Movable):
    """Location path: ordered steps (each step is an `XPathExpr` with `XPathStep` payload).
    """

    var steps: List[Arc[XPathExpr]]


@fieldwise_init
struct XPathStep(Movable):
    """Axis/step name is `XPathExpr.value`; bracket predicates only."""

    var predicates: List[Arc[XPathExpr]]


comptime XPathPayload = Variant[
    XPathAtom,
    XPathBinaryOp,
    XPathCall,
    XPathPath,
    XPathStep,
]

# -----------------------------
# XPathExpr (tree nodes owned via Arc; children in payload also use Arc)
# -----------------------------


struct XPathExpr(Movable):
    """AST node: span token `value` plus a `payload` variant for structure."""

    comptime Kind = UInt8
    comptime NUMBER: Self.Kind = 0
    comptime STRING: Self.Kind = 1
    comptime NAME: Self.Kind = 2
    comptime BINARY: Self.Kind = 3
    comptime CALL: Self.Kind = 4
    comptime PATH: Self.Kind = 5
    comptime STEP: Self.Kind = 6

    var value: Token
    var payload: XPathPayload

    def __init__(out self, var value: Token, var payload: XPathPayload):
        self.value = value^
        self.payload = payload^

    def kind(read self) -> Self.Kind:
        if self.payload.isa[XPathBinaryOp]():
            return Self.BINARY
        if self.payload.isa[XPathCall]():
            return Self.CALL
        if self.payload.isa[XPathPath]():
            return Self.PATH
        if self.payload.isa[XPathStep]():
            return Self.STEP
        var ty = self.value.type
        if ty == Token.NUMBER or ty == Token.FLOAT_NUMBER:
            return Self.NUMBER
        if ty == Token.STRING:
            return Self.STRING
        return Self.NAME

    @staticmethod
    def number(var v: Token) -> Arc[Self]:
        var node = Self(v^, XPathPayload(XPathAtom()))
        return Arc[Self](node^)

    @staticmethod
    def string(var v: Token) -> Arc[Self]:
        var node = Self(v^, XPathPayload(XPathAtom()))
        return Arc[Self](node^)

    @staticmethod
    def name(var v: Token) -> Arc[Self]:
        var node = Self(v^, XPathPayload(XPathAtom()))
        return Arc[Self](node^)

    @staticmethod
    def binary(
        var op: Token, var lhs: Arc[Self], var rhs: Arc[Self]
    ) -> Arc[Self]:
        var node = Self(
            op^,
            XPathPayload(XPathBinaryOp(lhs^, rhs^)),
        )
        return Arc[Self](node^)

    @staticmethod
    def call(var name: Token, var args: List[Arc[Self]]) -> Arc[Self]:
        var node = Self(
            name^,
            XPathPayload(XPathCall(args^)),
        )
        return Arc[Self](node^)

    @staticmethod
    def path(var steps: List[Arc[Self]]) -> Arc[Self]:
        var empty_tok = Token(type=Token.EOF, start=0, length=0, line=0)
        var node = Self(
            empty_tok^,
            XPathPayload(XPathPath(steps^)),
        )
        return Arc[Self](node^)

    @staticmethod
    def step(var name: Token, var predicates: List[Arc[Self]]) -> Arc[Self]:
        var node = Self(
            name^,
            XPathPayload(XPathStep(predicates^)),
        )
        return Arc[Self](node^)


# -----------------------------
# Visitor pattern for XPathExpr (stateful visitor + ``XPathContext`` for token spans).
# -----------------------------


struct XPathContext[origin: ImmutOrigin](Movable):
    """UTF-8 expression buffer view for ``Token.text`` / span-based lexemes (``ByteView`` = ``Span[Byte, origin]``).
    """

    var source: ByteView[Self.origin]

    def __init__(out self, source: ByteView[Self.origin]):
        self.source = source


## Walk ``XPathExpr`` by implementing ``visit_*`` on the enclosing ``expr`` (``expr.value`` holds span tokens; use ``expr.payload[...]`` when structure is needed).
## Dispatch with ``accept(mut visitor, node, ctx)``; recurse with the same ``ref ctx``.
trait XPathExprVisitor:
    def visit_number[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ...

    def visit_string[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ...

    def visit_name[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ...

    def visit_binary[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ...

    def visit_call[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ...

    def visit_path[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ...

    def visit_step[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ...


def accept[V: XPathExprVisitor, origin: ImmutOrigin](
    mut visitor: V, ref node: XPathExpr, ref ctx: XPathContext[origin]
) raises -> None:
    if node.kind() == XPathExpr.PATH:
        visitor.visit_path(node, ctx)
        return
    if node.kind() == XPathExpr.STEP:
        visitor.visit_step(node, ctx)
        return
    if node.kind() == XPathExpr.NUMBER:
        visitor.visit_number(node, ctx)
        return
    if node.kind() == XPathExpr.STRING:
        visitor.visit_string(node, ctx)
        return
    if node.kind() == XPathExpr.NAME:
        visitor.visit_name(node, ctx)
        return
    if node.kind() == XPathExpr.BINARY:
        visitor.visit_binary(node, ctx)
        return
    if node.kind() == XPathExpr.CALL:
        visitor.visit_call(node, ctx)
        return


def accept[V: XPathExprVisitor, origin: ImmutOrigin](
    mut visitor: V, root: Arc[XPathExpr], ref ctx: XPathContext[origin]
) raises -> None:
    accept(visitor, root[], ctx)


struct XPathExprStringifier(XPathExprVisitor):
    """Readable XPath text; build ``XPathContext`` from the parse source, then read ``result`` after ``accept``.
    """

    var result: String

    def __init__(out self):
        self.result = ""

    def visit_number[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        self.result = expr.value.text(ctx.source)

    def visit_string[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        self.result = (
            '"' + expr.value.text(ctx.source, strip_quotes=True) + '"'
        )

    def visit_name[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        self.result = expr.value.text(ctx.source)

    def visit_binary[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ref bin = expr.payload[XPathBinaryOp]
        accept(self, bin.left[], ctx)
        var left_val = self.result
        accept(self, bin.right[], ctx)
        var right_val = self.result
        self.result = (
            "("
            + left_val
            + " "
            + expr.value.text(ctx.source)
            + " "
            + right_val
            + ")"
        )

    def visit_call[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ref c = expr.payload[XPathCall]
        var out = expr.value.text(ctx.source) + "("
        for i in range(len(c.args)):
            if i > 0:
                out += ", "
            accept(self, c.args[i][], ctx)
            out += self.result
        out += ")"
        self.result = out

    def visit_path[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ref p = expr.payload[XPathPath]
        var out = ""
        for i in range(len(p.steps)):
            if i > 0:
                out += "/"
            accept(self, p.steps[i][], ctx)
            out += self.result
        self.result = out

    def visit_step[
        origin: ImmutOrigin
    ](mut self, ref expr: XPathExpr, ref ctx: XPathContext[origin]) raises -> None:
        ref st = expr.payload[XPathStep]
        var out = expr.value.text(ctx.source)
        for i in range(len(st.predicates)):
            accept(self, st.predicates[i][], ctx)
            out += "[" + self.result + "]"
        self.result = out


# -----------------------------
# Parser
# -----------------------------


struct Parser:
    """Parses by pulling the next token on demand from the tokenizer."""

    var _tokenizer: XPathTokenizer
    var _current: Token

    def __init__(out self, var tokenizer: XPathTokenizer) raises:
        self._tokenizer = tokenizer^
        self._current = self._tokenizer.next_token()

    # -----------------------------
    # Token Cursor (parser asks for next token via advance)
    # -----------------------------

    def current(self) -> ref[self._current] Token:
        return self._current

    def advance(mut self) raises -> Token:
        var next = self._tokenizer.next_token()  # Need to do this first!
        var move_current = self._current^
        self._current = next^
        return move_current^

    def skip(mut self) raises:
        self._current = self._tokenizer.next_token()

    def match(mut self, t: Token.Type) raises -> Bool:
        if self.current().type == t:
            self.skip()
            return True
        return False

    def expect(mut self, t: Token.Type) raises -> Token:
        var curType = self.current().type
        if curType != t:
            raise Error(
                "Unexpected token type "
                + Token.type_name(curType)
                + " (expected "
                + Token.type_name(t)
                + ")"
            )
        return self.advance()

    def skip_or_raise(mut self, t: Token.Type) raises -> None:
        """Skip current token if its type is t; otherwise raise. Does not return the token.
        """
        if self._current.type != t:
            raise Error(
                "Unexpected token type "
                + Token.type_name(self._current.type)
                + " (expected "
                + Token.type_name(t)
                + ")"
            )
        self.skip()

    def expect_step_name(mut self) raises -> Token:
        var curType = self.current().type
        if curType != Token.IDENTIFIER and curType != Token.QNAME:
            raise Error(
                "Unexpected token type "
                + Token.type_name(curType)
                + " (expected IDENTIFIER or QNAME)"
            )
        return self.advance()

    ## Return the lexeme string for token t (span-based tokens reference expression via tokenizer).
    def _lexeme(ref self, t: Token) raises -> String:
        return self._tokenizer.token_text(t)

    ## Return the string value for token t (lexeme with surrounding quotes stripped).
    def _unquoted_string_text(ref self, t: Token) raises -> String:
        return self._tokenizer.token_unquoted_string_text(t)

    # -----------------------------
    # Pratt Expression Parser
    # -----------------------------

    def parse_expression(mut self, min_bp: Int = 0) raises -> Arc[XPathExpr]:
        var lhs = self.parse_prefix()

        while True:
            ref tok = self.current()

            var bp = self.infix_binding_power(tok)
            var lbp = bp[0]
            var rbp = bp[1]

            if lbp < min_bp or lbp == 0:
                break

            var op_tok = self.advance()

            var rhs = self.parse_expression(rbp)

            lhs = XPathExpr.binary(op_tok^, lhs, rhs)

        return lhs

    # -----------------------------
    # Prefix Expressions
    # -----------------------------

    def parse_prefix(mut self) raises -> Arc[XPathExpr]:
        var tok = self.advance()

        if tok.type == Token.NUMBER or tok.type == Token.FLOAT_NUMBER:
            return XPathExpr.number(tok^)

        if tok.type == Token.STRING:
            return XPathExpr.string(tok^)

        if (
            tok.type == Token.IDENTIFIER
            or tok.type == Token.QNAME
            or tok.type == Token.KW_OR
            or tok.type == Token.KW_AND
            or tok.type == Token.KW_DIV
            or tok.type == Token.KW_MOD
        ):
            if self.current().type == Token.PAREN_OPEN:
                if tok.type == Token.IDENTIFIER or tok.type == Token.QNAME:
                    return self.parse_function_call(tok^)
                raise Error("Unexpected '(' after " + Token.type_name(tok.type))
            return self._name_or_step_with_predicates(tok^)

        if tok.type == Token.PAREN_OPEN:
            _ = tok^
            var expr = self.parse_expression()
            # Accept parenthesized comma lists used by some x-yang `must` rules,
            # e.g. ../type = ('date','datetime').
            while self.current().type == Token.COMMA:
                var comma_tok = self.expect(Token.COMMA)
                var rhs = self.parse_expression()
                expr = XPathExpr.binary(comma_tok^, expr, rhs)
            self.skip_or_raise(Token.PAREN_CLOSE)
            return expr

        if tok.type == Token.SLASH:
            _ = tok^
            return self.parse_location_path()

        if tok.type == Token.DOT:
            return self._name_or_step_with_predicates(tok^)

        if tok.type == Token.DOTDOT:
            return self._name_or_step_with_predicates(tok^)

        raise Error("Unexpected token")

    # -----------------------------
    # Infix Operator Precedence
    # -----------------------------

    def infix_binding_power(self, tok: Token) raises -> Tuple[Int, Int]:
        var ty = tok.type
        if ty == Token.KW_OR:
            return Tuple[Int, Int](1, 2)
        if ty == Token.KW_AND:
            return Tuple[Int, Int](3, 4)

        if ty == Token.EQ or ty == Token.NE:
            return Tuple[Int, Int](5, 6)

        if ty == Token.LT or ty == Token.GT or ty == Token.LE or ty == Token.GE:
            return Tuple[Int, Int](7, 8)

        if ty == Token.PLUS or ty == Token.MINUS:
            return Tuple[Int, Int](9, 10)

        if ty == Token.STAR or ty == Token.KW_DIV or ty == Token.KW_MOD:
            return Tuple[Int, Int](11, 12)

        if ty == Token.SLASH:
            return Tuple[Int, Int](13, 14)

        return Tuple[Int, Int](0, 0)

    # -----------------------------
    # Name or step with optional predicates (e.g. entities[1] or .[position()=1])
    # -----------------------------

    def _name_or_step_with_predicates(
        mut self, var tok: Token
    ) raises -> Arc[XPathExpr]:
        var predicates = List[Arc[XPathExpr]]()
        while self.current().type == Token.BRACKET_OPEN:
            var pred_arc = self.parse_predicate()
            predicates.append(pred_arc^)
        if len(predicates) > 0:
            return XPathExpr.step(tok^, predicates^)
        return XPathExpr.name(tok^)

    # -----------------------------
    # Function Calls
    # -----------------------------

    def parse_function_call(
        mut self, var name_tok: Token
    ) raises -> Arc[XPathExpr]:
        self.skip_or_raise(Token.PAREN_OPEN)

        var args = List[Arc[XPathExpr]]()

        if self.current().type != Token.PAREN_CLOSE:
            while True:
                var arg_arc = self.parse_expression()
                args.append(arg_arc^)

                if not self.match(Token.COMMA):
                    break

        self.skip_or_raise(Token.PAREN_CLOSE)

        return XPathExpr.call(name_tok^, args^)

    # -----------------------------
    # Location Paths
    # -----------------------------

    def parse_location_path(mut self) raises -> Arc[XPathExpr]:
        var steps = List[Arc[XPathExpr]]()

        while True:
            var step_arc = self.parse_step()
            steps.append(step_arc^)

            if self.current().type != Token.SLASH:
                break

            self.skip()

        return XPathExpr.path(steps^)

    # -----------------------------
    # Path Steps
    # -----------------------------

    def parse_step(mut self) raises -> Arc[XPathExpr]:
        var tok = self.expect_step_name()

        var predicates = List[Arc[XPathExpr]]()

        while self.current().type == Token.BRACKET_OPEN:
            var pred_arc = self.parse_predicate()
            predicates.append(pred_arc^)

        return XPathExpr.step(tok^, predicates^)

    # -----------------------------
    # Predicates
    # -----------------------------

    def parse_predicate(mut self) raises -> Arc[XPathExpr]:
        self.skip_or_raise(Token.BRACKET_OPEN)

        var expr = self.parse_expression()

        self.skip_or_raise(Token.BRACKET_CLOSE)

        return expr


# -----------------------------
# Entry Point
# -----------------------------


def parse_xpath(read expression: String) raises -> Arc[XPathExpr]:
    """Parse an XPath expression string. Root is returned as an owning Arc."""
    var tokenizer = XPathTokenizer(expression)
    var parser = Parser(tokenizer^)
    return parser.parse_expression()


def parse_refine_path(read expression: String) raises -> Arc[XPathExpr]:
    """Parse a refine-style schema path (supports prefixed identifiers like mod:name). Root is an owning Arc.
    """
    var tokenizer = XPathTokenizer(expression)
    var parser = Parser(tokenizer^)

    var steps = List[Arc[XPathExpr]]()

    if parser.current().type == Token.SLASH:
        parser.skip()

    var first_step = parser.parse_step()
    steps.append(first_step^)

    while parser.current().type == Token.SLASH:
        parser.skip()
        var step_arc = parser.parse_step()
        steps.append(step_arc^)

    parser.skip_or_raise(Token.EOF)
    return XPathExpr.path(steps^)
