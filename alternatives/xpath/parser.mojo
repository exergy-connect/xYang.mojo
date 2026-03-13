## XPath parser for Mojo xYang, modeled after the Python xpath parser.
## Produces AST nodes defined in xyang.xpath.ast.

from std.collections import List
from std.collections.optional import Optional
from xyang.xpath.token import Token
from xyang.xpath.tokenizer import XPathTokenizer
from std.memory import ArcPointer
from xyang.xpath.ast import (
    ASTNodeVariant,
    BinaryOpNode,
    FunctionCallNode,
    LiteralNode,
    PathNode,
    PathSegment,
)

comptime Arc = ArcPointer


struct XPathParser:
    var expression: String
    var tokens: List[Arc[Token]]
    var position: Int

    def __init__(out self, expression: String):
        self.expression = expression
        var tokenizer = XPathTokenizer(expression)
        self.tokens = tokenizer.tokenize()
        self.position = 0

    def parse(mut self) -> ASTNodeVariant:
        """Parse a full XPath expression into a generic AST value."""
        if len(self.tokens) == 0 or self.tokens[0][].type == Token.EOF:
            raise Error("Empty expression")
        var node: ASTNodeVariant
        var _cacheable: Bool
        (node, _cacheable) = self._parse_expression()
        ref t = self._current()
        if t.type != Token.EOF:
            raise Error("Unexpected token in expression: " + t.value)
        return node

    def parse_path(mut self) -> PathNode:
        """Parse the expression strictly as a path and return a PathNode."""
        if len(self.tokens) == 0 or self.tokens[0][].type == Token.EOF:
            raise Error("Empty path expression")
        var t = self._current()
        var is_absolute = t.type == Token.SLASH
        if is_absolute:
            self._consume(Token.SLASH)
        var path: PathNode
        var _cacheable: Bool
        (path, _cacheable) = self._parse_path(is_absolute = is_absolute, first_step = None, allow_predicate = False)
        if self._current().type != Token.EOF:
            t = self._current()
            raise Error("Unexpected token after path: " + t.value)
        return path

    def _current(self) -> ref [self.tokens] Token:
        if self.position < len(self.tokens):
            return self.tokens[self.position][]
        return Token(type = Token.EOF, value = "", position = 0)

    ## Consume and return the current token if it matches expected_type.
    def _consume(mut self, expected_type: Token.Type) -> Token:
        var t = self._current()
        if t.type != expected_type:
            raise Error("Expected " + String(expected_type) + ", got " + String(t.type))
        self.position += 1
        return t.copy()

    ## Advance to the next token.
    def _advance(mut self):
        self.position += 1

    def _is_keyword(self, keyword: String) -> Bool:
        var t = self._current()
        return t.type == Token.IDENTIFIER and t.value.lower() == keyword.lower()

    def _parse_expression(mut self) -> Tuple[ASTNodeVariant, Bool]:
        return self._parse_logical_or()

    def _parse_logical_or(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var left: ASTNodeVariant
        var cacheable: Bool
        (left, cacheable) = self._parse_logical_and()
        while self._is_keyword("or"):
            self._advance()
            var right: ASTNodeVariant
            var rc: Bool
            (right, rc) = self._parse_logical_and()
            left = BinaryOpNode(left = left, operator = "or", right = right)
            cacheable = cacheable and rc
        return (left, cacheable)

    def _parse_logical_and(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var left: ASTNodeVariant
        var cacheable: Bool
        (left, cacheable) = self._parse_comparison()
        while self._is_keyword("and"):
            self._advance()
            var right: ASTNodeVariant
            var rc: Bool
            (right, rc) = self._parse_comparison()
            left = BinaryOpNode(left = left, operator = "and", right = right)
            cacheable = cacheable and rc
        return (left, cacheable)

    def _parse_comparison(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var left: ASTNodeVariant
        var cacheable: Bool
        (left, cacheable) = self._parse_additive()
        var t = self._current()
        if t.type == Token.OPERATOR and (
            t.value == "="
            or t.value == "!="
            or t.value == "<"
            or t.value == ">"
            or t.value == "<="
            or t.value == ">="
        ):
            var op = self._advance().value
            var right: ASTNodeVariant
            var rc: Bool
            (right, rc) = self._parse_additive()
            return (BinaryOpNode(left = left, operator = op, right = right), cacheable and rc)
        return (left, cacheable)

    def _parse_additive(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var left: ASTNodeVariant
        var cacheable: Bool
        (left, cacheable) = self._parse_multiplicative()
        while True:
            var t = self._current()
            if t.type == Token.OPERATOR and (t.value == "+" or t.value == "-"):
                var op = self._advance().value
                var right: ASTNodeVariant
                var rc: Bool
                (right, rc) = self._parse_multiplicative()
                left = BinaryOpNode(left = left, operator = op, right = right)
                cacheable = cacheable and rc
            else:
                break
        return (left, cacheable)

    def _parse_multiplicative(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var left: ASTNodeVariant
        var cacheable: Bool
        (left, cacheable) = self._parse_unary()
        while True:
            var t = self._current()
            if t.type == Token.SLASH:
                self._consume(Token.SLASH)
                var right_path: PathNode
                var rc: Bool
                (right_path, rc) = self._parse_path(is_absolute = False, first_step = None)
                left = BinaryOpNode(left = left, operator = "/", right = ASTNodeVariant(right_path))
                cacheable = cacheable and rc
            elif t.type == Token.OPERATOR and t.value == "*":
                _ = self._advance()
                var right: ASTNodeVariant
                var rc2: Bool
                (right, rc2) = self._parse_unary()
                left = BinaryOpNode(left = left, operator = "*", right = right)
                cacheable = cacheable and rc2
            else:
                break
        return (left, cacheable)

    def _parse_unary(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var t = self._current()
        if t.type == Token.OPERATOR and t.value == "-":
            self._advance()
            var operand: ASTNodeVariant
            var _c: Bool
            (operand, _c) = self._parse_unary()
            return (BinaryOpNode(left = ASTNodeVariant(LiteralNode(value = "0")), operator = "-", right = operand), False)
        if t.type == Token.OPERATOR and t.value == "+":
            self._advance()
            return self._parse_unary()
        if self._is_keyword("not"):
            _ = self._advance()
            self._consume(Token.PAREN_OPEN)
            var operand2: ASTNodeVariant
            var _c2: Bool
            (operand2, _c2) = self._parse_expression()
            self._consume(Token.PAREN_CLOSE)
            var not_args = List[ASTNodeVariant]()
            not_args.append(operand2)
            return (FunctionCallNode(name = "not", args = not_args^), False)
        return self._parse_primary()

    def _parse_primary(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var t = self._current()
        if t.type == Token.STRING:
            var value = self._advance().value
            return (LiteralNode(value = value), False)
        if t.type == Token.NUMBER:
            var raw = self._advance().value
            var is_int = True
            if raw.find(".") >= 0:
                is_int = False
            # very simple number handling; rely on caller to interpret
            return (LiteralNode(value = raw), is_int)
        if t.type == Token.IDENTIFIER:
            if self._is_keyword("true"):
                _ = self._advance()
                return (LiteralNode(value = "true"), False)
            if self._is_keyword("false"):
                _ = self._advance()
                return (LiteralNode(value = "false"), False)
            # function call vs path
            if (
                self.position + 1 < len(self.tokens)
                and self.tokens[self.position + 1][].type == Token.PAREN_OPEN
            ):
                return self._parse_function_call()
            return self._parse_path(is_absolute = False, first_step = None)
        if t.type == Token.DOT:
            self._advance()
            return self._parse_path(is_absolute = False, first_step = ".")
        if t.type == Token.DOTDOT:
            self._advance()
            return self._parse_path(is_absolute = False, first_step = "..")
        if t.type == Token.SLASH:
            self._advance()
            return self._parse_path(is_absolute = True, first_step = None)
        if t.type == Token.PAREN_OPEN:
            self._advance()
            var expr: ASTNodeVariant
            var cacheable: Bool
            (expr, cacheable) = self._parse_expression()
            self._consume(Token.PAREN_CLOSE)
            return (expr, cacheable)
        raise Error("Unexpected token in primary: " + t.value)

    def _parse_function_call(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var name = self._advance().value
        self._consume(Token.PAREN_OPEN)
        var args = List[ASTNodeVariant]()
        if self._current().type != Token.PAREN_CLOSE:
            var node: ASTNodeVariant
            var _c: Bool
            (node, _c) = self._parse_expression()
            args.append(node)
            while self._current().type == Token.COMMA:
                self._advance()
                var node2: ASTNodeVariant
                var _c2: Bool
                (node2, _c2) = self._parse_expression()
                args.append(node2)
        self._consume(Token.PAREN_CLOSE)
        return (FunctionCallNode(name = name, args = args^), False)

    def _parse_path(
        mut self,
        is_absolute: Bool,
        first_step: Optional[String] = None,
        allow_predicate: Bool = True,
    ) -> Tuple[PathNode, Bool]:
        var segments = List[Arc[PathSegment]]()
        var cacheable = is_absolute
        var no_predicate = Optional[String]()

        if first_step:
            var seg = PathSegment(step = first_step.value, predicate = no_predicate)
            segments.append(Arc[PathSegment](seg^))
            if self._current().type == Token.SLASH:
                self._advance()
            else:
                return (PathNode(segments = segments^, is_absolute = is_absolute, is_cacheable = cacheable), cacheable)

        while True:
            var t = self._current()
            if t.type != Token.DOT and t.type != Token.DOTDOT and t.type != Token.IDENTIFIER:
                break
            var step = self._consume(t.type).value
            var seg = PathSegment(step = step, predicate = no_predicate)
            segments.append(Arc[PathSegment](seg^))
            if self._current().type != Token.SLASH:
                break
            self._advance()

        return (PathNode(segments = segments^, is_absolute = is_absolute, is_cacheable = cacheable), cacheable)

