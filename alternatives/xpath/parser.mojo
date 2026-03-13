## XPath parser for Mojo xYang, modeled after the Python xpath parser.
## Produces AST nodes defined in alternatives.xpath.ast (same folder).

from std.collections import List
from std.collections.optional import Optional
from xyang.xpath.token import Token
from xyang.xpath.tokenizer import XPathTokenizer
from std.memory import ArcPointer
from alternatives.xpath.ast import (
    ASTNodeVariant,
    BinaryOpNode,
    FunctionCallNode,
    LiteralNode,
    PathNode,
    PathSegment,
)

comptime Arc = ArcPointer

@fieldwise_init
struct _PathResult(Movable):
    var path: PathNode
    var cacheable: Bool


struct XPathParser:
    var expression: String
    var tokenizer: XPathTokenizer
    var current_token: Token
    var _lookahead: Optional[Token]

    def __init__(out self, expression: String):
        self.expression = expression
        self.tokenizer = XPathTokenizer(expression)
        self.current_token = self.tokenizer.next_token()
        self._lookahead = None

    ## Peek at the next token (pulls from tokenizer if not already cached).
    def _peek_next(mut self) -> Token.Type:
        if not self._lookahead:
            self._lookahead = Optional(self.tokenizer.next_token())
        return self._lookahead.value().type

    def parse(mut self) -> ASTNodeVariant:
        """Parse a full XPath expression into a generic AST value."""
        if self.current_token.type == Token.EOF:
            raise Error("Empty expression")
        var node: ASTNodeVariant
        var _cacheable: Bool
        (node, _cacheable) = self._parse_expression()
        var t = self._current()
        if t.type != Token.EOF:
            raise Error("Unexpected token in expression: " + self._token_text(t))
        return node

    def parse_path(mut self) -> PathNode:
        """Parse the expression strictly as a path and return a PathNode."""
        if self.current_token.type == Token.EOF:
            raise Error("Empty path expression")
        var t = self._current()
        var is_absolute = t.type == Token.SLASH
        if is_absolute:
            self._expect(Token.SLASH)
        var res = self._parse_path(is_absolute=is_absolute, first_step=None, allow_predicate=False)
        var path = res.path.copy()
        if self._current().type != Token.EOF:
            t = self._current()
            raise Error("Unexpected token after path: " + self._token_text(t))
        return path^

    def _current(self) -> Token:
        return self.current_token.copy()

    ## Lexeme for token t (span-based tokens use expression).
    def _token_text(self, t: Token) -> String:
        return t.text(self.expression)

    ## Lexeme with quotes stripped; for STRING tokens.
    def _token_string_value(self, t: Token) -> String:
        return t.text(self.expression, strip_quotes=True)

    ## Consume and return the current token if it matches expected_type.
    ## Expect current token to match expected_type; advance. No token copy returned.
    def _expect(mut self, expected_type: Token.Type):
        if self.current_token.type != expected_type:
            raise Error("Expected {}, got {} ('{}') at line {}".format(Token.type_name(expected_type), Token.type_name(self.current_token.type), self._token_text(self.current_token), self.current_token.line))
        self._advance()

    def _consume(mut self, expected_type: Token.Type) -> Token:
        var t = self.current_token.copy()
        self._expect(expected_type)
        return t^

    ## Advance to the next token (use lookahead if set, else pull from tokenizer).
    def _advance(mut self):
        if self._lookahead:
            self.current_token = self._lookahead.value().copy()
            self._lookahead = None
        else:
            self.current_token = self.tokenizer.next_token()

    def _is_keyword(self, keyword: String) -> Bool:
        var t = self._current()
        return t.type == Token.IDENTIFIER and self._token_text(t).lower() == keyword.lower()

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
        var op_str = self._token_text(t)
        if t.type == Token.OPERATOR and (
            op_str == "="
            or op_str == "!="
            or op_str == "<"
            or op_str == ">"
            or op_str == "<="
            or op_str == ">="
        ):
            self._advance()
            var op = op_str
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
            var op_str = self._token_text(t)
            if t.type == Token.OPERATOR and (op_str == "+" or op_str == "-"):
                self._advance()
                var op = op_str
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
                self._expect(Token.SLASH)
                var rres = self._parse_path(is_absolute=False, first_step=None)
                var right_path = rres.path.copy()
                left = BinaryOpNode(left = left, operator = "/", right = ASTNodeVariant(right_path^))
                cacheable = cacheable and rres.cacheable
            elif t.type == Token.OPERATOR and self._token_text(t) == "*":
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
        if t.type == Token.OPERATOR and self._token_text(t) == "-":
            self._advance()
            var operand: ASTNodeVariant
            var _c: Bool
            (operand, _c) = self._parse_unary()
            return (BinaryOpNode(left = ASTNodeVariant(LiteralNode(value = "0")), operator = "-", right = operand), False)
        if t.type == Token.OPERATOR and self._token_text(t) == "+":
            self._advance()
            return self._parse_unary()
        if self._is_keyword("not"):
            self._advance()
            self._expect(Token.PAREN_OPEN)
            var operand2: ASTNodeVariant
            var _c2: Bool
            (operand2, _c2) = self._parse_expression()
            self._expect(Token.PAREN_CLOSE)
            var not_args = List[Arc[ASTNodeVariant]]()
            not_args.append(Arc[ASTNodeVariant](operand2^))
            return (FunctionCallNode(name = "not", args = not_args^), False)
        return self._parse_primary()

    def _parse_primary(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var t = self._current()
        if t.type == Token.STRING:
            var value = self._token_string_value(t)
            self._advance()
            return (LiteralNode(value = value), False)
        if t.type == Token.NUMBER:
            var raw = self._token_text(t)
            self._advance()
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
            # function call vs path (peek next token)
            if self._peek_next() == Token.PAREN_OPEN:
                return self._parse_function_call()
            var pres = self._parse_path(is_absolute=False, first_step=None)
            var p = pres.path.copy()
            return (ASTNodeVariant(p^), pres.cacheable)
        if t.type == Token.DOT:
            self._advance()
            var pres = self._parse_path(is_absolute=False, first_step=".")
            var p = pres.path.copy()
            return (ASTNodeVariant(p^), pres.cacheable)
        if t.type == Token.DOTDOT:
            self._advance()
            var pres = self._parse_path(is_absolute=False, first_step="..")
            var p = pres.path.copy()
            return (ASTNodeVariant(p^), pres.cacheable)
        if t.type == Token.SLASH:
            self._advance()
            var pres = self._parse_path(is_absolute=True, first_step=None)
            var p = pres.path.copy()
            return (ASTNodeVariant(p^), pres.cacheable)
        if t.type == Token.PAREN_OPEN:
            self._advance()
            var expr: ASTNodeVariant
            var cacheable: Bool
            (expr, cacheable) = self._parse_expression()
            self._expect(Token.PAREN_CLOSE)
            return (expr, cacheable)
        raise Error("Unexpected token in primary: " + self._token_text(t))

    def _parse_function_call(mut self) -> Tuple[ASTNodeVariant, Bool]:
        var name = self._token_text(self._current())
        self._advance()
        self._expect(Token.PAREN_OPEN)
        var args = List[Arc[ASTNodeVariant]]()
        if self._current().type != Token.PAREN_CLOSE:
            var node: ASTNodeVariant
            var _c: Bool
            (node, _c) = self._parse_expression()
            args.append(Arc[ASTNodeVariant](node^))
            while self._current().type == Token.COMMA:
                self._advance()
                var node2: ASTNodeVariant
                var _c2: Bool
                (node2, _c2) = self._parse_expression()
                args.append(Arc[ASTNodeVariant](node2^))
        self._expect(Token.PAREN_CLOSE)
        return (FunctionCallNode(name = name, args = args^), False)

    def _parse_path(
        mut self,
        is_absolute: Bool,
        first_step: Optional[String] = None,
        allow_predicate: Bool = True,
    ) -> _PathResult:
        var segments = List[Arc[PathSegment]]()
        var cacheable = is_absolute
        var no_predicate = Optional[String]()

        if first_step:
            var seg = PathSegment(step = first_step.value(), predicate = no_predicate)
            segments.append(Arc[PathSegment](seg^))
            if self._current().type == Token.SLASH:
                self._advance()
            else:
                var p = PathNode(segments = segments^, is_absolute = is_absolute, is_cacheable = cacheable)
                return _PathResult(p^, cacheable)

        while True:
            var t = self._current()
            if t.type != Token.DOT and t.type != Token.DOTDOT and t.type != Token.IDENTIFIER:
                break
            var consumed = self._consume(t.type)
            var step = self._token_text(consumed)
            var seg = PathSegment(step = step, predicate = no_predicate)
            segments.append(Arc[PathSegment](seg^))
            if self._current().type != Token.SLASH:
                break
            self._advance()

        var p = PathNode(segments = segments^, is_absolute = is_absolute, is_cacheable = cacheable)
        return _PathResult(p^, cacheable)

