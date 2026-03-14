from std.collections import List
from std.memory import ArcPointer, UnsafePointer, alloc
from xyang.xpath.token import Token
from xyang.xpath.tokenizer import XPathTokenizer
from sys.intrinsics import likely, unlikely

comptime Arc = ArcPointer

# -----------------------------
# AST Nodes (self-referential via UnsafePointer per Mojo docs)
# https://docs.modular.com/mojo/manual/structs/reference/
# -----------------------------

struct Expr(Movable):
    """AST node for expressions and path steps (step = kind 'step', value = name, args = predicates).
    Uses UnsafePointer per https://docs.modular.com/mojo/manual/structs/reference/.
    """

    comptime ExprPointer = UnsafePointer[Self, MutExternalOrigin]

    comptime Kind = UInt8
    comptime NUMBER: Self.Kind = 0
    comptime STRING: Self.Kind = 1
    comptime NAME: Self.Kind = 2
    comptime BINARY: Self.Kind = 3
    comptime CALL: Self.Kind = 4
    comptime PATH: Self.Kind = 5
    comptime STEP: Self.Kind = 6

    ## Node variant (Expr.NUMBER, Expr.STRING, …).
    var kind: Self.Kind
    ## Span-based token for literal/name/op/call/step; use .value.text(source) to get lexeme. For PATH, a sentinel token (length 0).
    var value: Token
    ## Left operand of a binary expression (e.g. lhs of "a + b"). Unused (empty) for other kinds.
    var left: Self.ExprPointer
    ## Right operand of a binary expression (e.g. rhs of "a + b"). Unused (empty) for other kinds.
    var right: Self.ExprPointer
    ## For "call": function arguments. For "step": predicates (e.g. [1], [. = "x"]). Unused for other kinds.
    var args: List[Arc[Expr]]
    ## For "path" only: ordered list of steps (each step is an Expr with kind "step"). Unused for other kinds.
    var steps: List[Arc[Expr]]

    def __init__(
        out self,
        kind: Self.Kind,
        value: Token,
        left: Self.ExprPointer,
        right: Self.ExprPointer,
        var args: List[Arc[Expr]],
        var steps: List[Arc[Expr]],
    ):
        self.kind = kind
        self.value = value.copy()
        self.left = left
        self.right = right
        self.args = args^
        self.steps = steps^

    @staticmethod
    def number(v: Token) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                Self.NUMBER, v,
                Self.ExprPointer(),
                Self.ExprPointer(),
                List[Arc[Expr]](),
                List[Arc[Expr]](),
            )
        )
        return ptr

    @staticmethod
    def string(v: Token) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                Self.STRING, v,
                Self.ExprPointer(),
                Self.ExprPointer(),
                List[Arc[Expr]](),
                List[Arc[Expr]](),
            )
        )
        return ptr

    @staticmethod
    def name(v: Token) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                Self.NAME, v,
                Self.ExprPointer(),
                Self.ExprPointer(),
                List[Arc[Expr]](),
                List[Arc[Expr]](),
            )
        )
        return ptr

    @staticmethod
    def binary(op: Token, lhs: Self.ExprPointer, rhs: Self.ExprPointer) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                Self.BINARY, op,
                lhs,
                rhs,
                List[Arc[Expr]](),
                List[Arc[Expr]](),
            )
        )
        return ptr

    @staticmethod
    def call(name: Token, var args: List[Arc[Expr]]) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                Self.CALL, name,
                Self.ExprPointer(),
                Self.ExprPointer(),
                args^,
                List[Arc[Expr]](),
            )
        )
        return ptr

    @staticmethod
    def path(var steps: List[Arc[Expr]]) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        var empty_tok = Token(type=Token.EOF, start=0, length=0, line=0)
        ptr.init_pointee_move(
            Self(
                Self.PATH, empty_tok,
                Self.ExprPointer(),
                Self.ExprPointer(),
                List[Arc[Expr]](),
                steps^,
            )
        )
        return ptr

    @staticmethod
    def step(name: Token, var predicates: List[Arc[Expr]]) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                Self.STEP, name,
                Self.ExprPointer(),
                Self.ExprPointer(),
                predicates^,
                List[Arc[Expr]](),
            )
        )
        return ptr

    ## Recursively free this node and all children. Call on the pointee (ptr[]).
    def free_tree(self):
        if self.left:
            self.left[].free_tree()
            self.left.destroy_pointee()
            self.left.free()
        if self.right:
            self.right[].free_tree()
            self.right.destroy_pointee()
            self.right.free()
        for i in range(len(self.args)):
            self.args[i][].free_tree()
        for i in range(len(self.steps)):
            self.steps[i][].free_tree()


# -----------------------------
# Visitor pattern for Expr
# -----------------------------

struct ExprContext:
    """Context passed to Expr visitors (e.g. source expression for token resolution)."""
    var expression: String

    fn __init__(out self, expression: String = ""):
        self.expression = expression


## Visitor for walking the Expr AST. Implement this to evaluate or transform the tree.
## Use accept(visitor, node, ctx) to dispatch; inside visit_* recurse by calling accept(visitor, child_ref, ctx).
trait ExprVisitor:
    def visit_number(self, ref node: Expr, ctx: ExprContext) -> String:
        return ""

    def visit_string(self, ref node: Expr, ctx: ExprContext) -> String:
        return ""

    def visit_name(self, ref node: Expr, ctx: ExprContext) -> String:
        return ""

    def visit_binary(self, ref node: Expr, ctx: ExprContext) -> String:
        return ""

    def visit_call(self, ref node: Expr, ctx: ExprContext) -> String:
        return ""

    def visit_path(self, ref node: Expr, ctx: ExprContext) -> String:
        return ""

    def visit_step(self, ref node: Expr, ctx: ExprContext) -> String:
        return ""


## Dispatch to the appropriate visitor method. Recurse from within visit_* by calling this again with child refs (e.g. node.left[], node.args[i][]).
def accept[V: ExprVisitor](visitor: V, ref node: Expr, ctx: ExprContext) -> String:
    if node.kind == Expr.PATH:
        return visitor.visit_path(node, ctx)
    if node.kind == Expr.STEP:
        return visitor.visit_step(node, ctx)
    if node.kind == Expr.NUMBER:
        return visitor.visit_number(node, ctx)
    if node.kind == Expr.STRING:
        return visitor.visit_string(node, ctx)
    if node.kind == Expr.NAME:
        return visitor.visit_name(node, ctx)
    if node.kind == Expr.BINARY:
        return visitor.visit_binary(node, ctx)
    if node.kind == Expr.CALL:
        return visitor.visit_call(node, ctx)
    return ""


## Convenience: dispatch from root pointer. Use when you have the result of parse_xpath().
def accept[V: ExprVisitor](visitor: V, root: Expr.ExprPointer, ctx: ExprContext) -> String:
    return accept(visitor, root[], ctx)


struct ExprStringifier(ExprVisitor):
    """Concrete visitor that produces a readable string representation of the Expr tree."""

    fn __init__(out self):
        pass

    def visit_number(self, ref node: Expr, ctx: ExprContext) -> String:
        return node.value.text(ctx.expression)

    def visit_string(self, ref node: Expr, ctx: ExprContext) -> String:
        return "\"" + node.value.text(ctx.expression, strip_quotes=True) + "\""

    def visit_name(self, ref node: Expr, ctx: ExprContext) -> String:
        return node.value.text(ctx.expression)

    def visit_binary(self, ref node: Expr, ctx: ExprContext) -> String:
        var left_val = ""
        var right_val = ""
        if node.left:
            left_val = accept(self, node.left[], ctx)
        if node.right:
            right_val = accept(self, node.right[], ctx)
        return "(" + left_val + " " + node.value.text(ctx.expression) + " " + right_val + ")"

    def visit_call(self, ref node: Expr, ctx: ExprContext) -> String:
        var out = node.value.text(ctx.expression) + "("
        for i in range(len(node.args)):
            if i > 0:
                out += ", "
            out += accept(self, node.args[i][], ctx)
        out += ")"
        return out

    def visit_path(self, ref node: Expr, ctx: ExprContext) -> String:
        var out = ""
        for i in range(len(node.steps)):
            if i > 0:
                out += "/"
            out += accept(self, node.steps[i][], ctx)
        return out

    def visit_step(self, ref node: Expr, ctx: ExprContext) -> String:
        var out = node.value.text(ctx.expression)
        for i in range(len(node.args)):
            out += "[" + accept(self, node.args[i][], ctx) + "]"
        return out


# -----------------------------
# Parser
# -----------------------------

struct Parser:
    """Parses by pulling the next token on demand from the tokenizer."""

    var _tokenizer: XPathTokenizer
    var _current: Token

    def __init__(out self, var tokenizer: XPathTokenizer):
        self._tokenizer = tokenizer^
        self._current = self._tokenizer.next_token()

    # -----------------------------
    # Token Cursor (parser asks for next token via advance)
    # -----------------------------

    def current(self) -> ref[self._current] Token:
        return self._current

    def advance(mut self) -> Token:
        var next = self._tokenizer.next_token()  # Need to do this first!
        var move_current = self._current^
        self._current = next^
        return move_current^

    def skip(mut self):
        self._current = self._tokenizer.next_token()

    def match(mut self, t: Token.Type) -> Bool:
        if self.current().type == t:
            self.skip()
            return True
        return False

    def expect(mut self, t: Token.Type) -> Token:
        var curType = self.current().type
        if curType != t:
            raise Error("Unexpected token type " + Token.type_name(curType) + 
                        " (expected " + Token.type_name(t) + ")")
        return self.advance()
    
    # def expect[ReturnToken: Bool = False](
    #     mut self, 
    #     t: Token.Type
    # ) -> Token if ReturnToken else None:
    #     ref cur = self.current()
    #     if unlikely(cur.type != t):
    #         raise Error("Unexpected token type " + Token.type_name(cur.type) + " (expected " + Token.type_name(t) + ")")
    #     self.skip()
    #     if ReturnToken:
    #         return cur.copy()

    def skip_or_raise(mut self, t: Token.Type) -> None:
        """Skip current token if its type is t; otherwise raise. Does not return the token."""
        if self._current.type != t:
            raise Error("Unexpected token type " + Token.type_name(self._current.type) + " (expected " + Token.type_name(t) + ")")
        self.skip()

    ## Return the lexeme string for token t (span-based tokens reference expression via tokenizer).
    def _lexeme(ref self, t: Token) -> String:
        return self._tokenizer.token_text(t)

    ## Return the string value for token t (lexeme with surrounding quotes stripped).
    def _unquoted_string_text(ref self, t: Token) -> String:
        return self._tokenizer.token_unquoted_string_text(t)

    # -----------------------------
    # Pratt Expression Parser
    # -----------------------------

    def parse_expression(mut self, min_bp: Int = 0) -> Expr.ExprPointer:

        var lhs = self.parse_prefix()

        while True:

            ref tok = self.current()

            var bp = self.infix_binding_power(tok)
            var lbp = bp[0]
            var rbp = bp[1]

            if lbp < min_bp or lbp == 0:
                break

            self.skip()

            var rhs = self.parse_expression(rbp)

            lhs = Expr.binary(tok.copy(), lhs, rhs)

        return lhs


    # -----------------------------
    # Prefix Expressions
    # -----------------------------

    def parse_prefix(mut self) -> Expr.ExprPointer:

        var tok = self.advance()

        if tok.type == Token.NUMBER or tok.type == Token.FLOAT_NUMBER:
            return Expr.number(tok.copy())

        if tok.type == Token.STRING:
            return Expr.string(tok.copy())

        if tok.type == Token.IDENTIFIER:
            if self.current().type == Token.PAREN_OPEN:
                return self.parse_function_call(tok)
            return self._name_or_step_with_predicates(tok)

        if tok.type == Token.PAREN_OPEN:
            var expr = self.parse_expression()
            self.skip_or_raise(Token.PAREN_CLOSE)
            return expr

        if tok.type == Token.SLASH:
            return self.parse_location_path()

        if tok.type == Token.DOT:
            return self._name_or_step_with_predicates(tok)

        if tok.type == Token.DOTDOT:
            return self._name_or_step_with_predicates(tok)

        raise Error("Unexpected token")


    # -----------------------------
    # Infix Operator Precedence
    # -----------------------------

    def infix_binding_power(self, tok: Token) -> Tuple[Int, Int]:

        var op = self._lexeme(tok)

        if op == "or":
            return Tuple[Int, Int](1, 2)

        if op == "and":
            return Tuple[Int, Int](3, 4)

        if op == "=" or op == "!=":
            return Tuple[Int, Int](5, 6)

        if op == "<" or op == ">":
            return Tuple[Int, Int](7, 8)

        if op == "+" or op == "-":
            return Tuple[Int, Int](9, 10)

        if op == "*" or op == "div" or op == "mod":
            return Tuple[Int, Int](11, 12)

        if op == "/" or op == "//":
            return Tuple[Int, Int](13, 14)

        return Tuple[Int, Int](0, 0)


    # -----------------------------
    # Name or step with optional predicates (e.g. entities[1] or .[position()=1])
    # -----------------------------

    def _name_or_step_with_predicates(mut self, tok: Token) -> Expr.ExprPointer:
        var predicates = List[Arc[Expr]]()
        while self.current().type == Token.BRACKET_OPEN:
            var pred_ptr = self.parse_predicate()
            predicates.append(Arc[Expr](pred_ptr.take_pointee()))
            pred_ptr.free()
        if len(predicates) > 0:
            return Expr.step(tok.copy(), predicates^)
        return Expr.name(tok.copy())

    # -----------------------------
    # Function Calls
    # -----------------------------

    def parse_function_call(mut self, name_tok: Token) -> Expr.ExprPointer:

        self.skip_or_raise(Token.PAREN_OPEN)

        var args = List[Arc[Expr]]()

        if self.current().type != Token.PAREN_CLOSE:

            while True:

                var ptr = self.parse_expression()
                args.append(Arc[Expr](ptr.take_pointee()))
                ptr.free()

                if not self.match(Token.COMMA):
                    break

        self.skip_or_raise(Token.PAREN_CLOSE)

        return Expr.call(name_tok.copy(), args^)


    # -----------------------------
    # Location Paths
    # -----------------------------

    def parse_location_path(mut self) -> Expr.ExprPointer:

        var steps = List[Arc[Expr]]()

        while True:

            var step_ptr = self.parse_step()
            steps.append(Arc[Expr](step_ptr.take_pointee()))
            step_ptr.free()

            if self.current().type != Token.SLASH:
                break

            self.skip()

        return Expr.path(steps^)


    # -----------------------------
    # Path Steps
    # -----------------------------

    def parse_step(mut self) -> Expr.ExprPointer:

        var tok = self.expect(Token.IDENTIFIER)

        var predicates = List[Arc[Expr]]()

        while self.current().type == Token.BRACKET_OPEN:
            var pred_ptr = self.parse_predicate()
            predicates.append(Arc[Expr](pred_ptr.take_pointee()))
            pred_ptr.free()

        return Expr.step(tok.copy(), predicates^)


    # -----------------------------
    # Predicates
    # -----------------------------

    def parse_predicate(mut self) -> Expr.ExprPointer:

        self.skip_or_raise(Token.BRACKET_OPEN)

        var expr = self.parse_expression()

        self.skip_or_raise(Token.BRACKET_CLOSE)

        return expr


# -----------------------------
# Entry Point
# -----------------------------

def parse_xpath(var expression: String) -> Expr.ExprPointer:
    """Parse an XPath expression string. Parser pulls tokens incrementally from the tokenizer."""
    var tokenizer = XPathTokenizer(expression)
    var parser = Parser(tokenizer^)
    return parser.parse_expression()