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
comptime ASTNode = Arc[ASTNodeVariant]

struct XPathParser:
    comptime ParseResult = Tuple[ASTNode, Bool]

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

    def parse(mut self) -> ASTNode:
        """Parse a full XPath expression into a generic AST value."""
        if self.current_token.type == Token.EOF:
            raise Error("Empty expression")
        var (node, _) = self._parse_expression()
        ref t = self._current()
        if t.type != Token.EOF:
            raise Error("Unexpected token in expression: " + self._token_text(t))
        return node^

    def parse_path(mut self) -> Arc[PathNode]:
        """Parse the expression strictly as a path and return a PathNode."""
        if self.current_token.type == Token.EOF:
            raise Error("Empty path expression")
        ref t = self._current()
        var is_absolute = t.type == Token.SLASH
        if is_absolute:
            self._expect(Token.SLASH)
        ( path, _c ) = self._parse_path(is_absolute=is_absolute, first_step=None, allow_predicate=False)
        if self._currentType() != Token.EOF:
            ref t2 = self._current()
            raise Error("Unexpected token after path: " + self._token_text(t2))
        return path

    def _current(self) -> ref[self.current_token] Token:
        return self.current_token

    def _currentType(self) -> Token.Type:
        return self.current_token.type

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
        ref t = self._current()
        return t.type == Token.IDENTIFIER and self._token_text(t).lower() == keyword.lower()

    def _parse_expression(mut self) -> Self.ParseResult:
        return self._parse_logical_or()

    def _parse_logical_or(mut self) -> Self.ParseResult:
        var left: ASTNode
        var cacheable: Bool
        (left, cacheable) = self._parse_comparison()

        while self._is_keyword("or"):
            var op_tok = self._current().copy()
            self._advance()
            var right: ASTNode
            var rc: Bool
            (right, rc) = self._parse_comparison()

            # Wrap the BinaryOpNode in ASTNodeVariant, then in Arc
            left = ASTNode(BinaryOpNode(
                left = left,
                operator = op_tok^,
                right = right
            ))
            cacheable = cacheable and rc

        return (left, cacheable)
    def _parse_logical_and(mut self) -> Self.ParseResult:
        var left: ASTNode
        var cacheable: Bool
        (left, cacheable) = self._parse_comparison()

        while self._is_keyword("and"):
            var op_tok = self._current().copy()
            self._advance()
            var right: ASTNode
            var rc: Bool
            (right, rc) = self._parse_comparison()

            # Wrap the BinaryOpNode in ASTNodeVariant, then in Arc
            left = ASTNode(BinaryOpNode(
                left = left,
                operator = op_tok^,
                right = right
            ))
            cacheable = cacheable and rc

        return (left, cacheable)

    def _parse_comparison(mut self) -> Self.ParseResult:
        var left: ASTNode
        var cacheable: Bool
        (left, cacheable) = self._parse_additive()
        ref t = self._current()
        var op_str = self._token_text(t)
        if t.type == Token.OPERATOR and (
            op_str == "="
            or op_str == "!="
            or op_str == "<"
            or op_str == ">"
            or op_str == "<="
            or op_str == ">="
        ):
            var op_tok = self._current().copy()
            self._advance()
            var right: ASTNode
            var rc: Bool
            (right, rc) = self._parse_additive()

            # Wrap the BinaryOpNode in ASTNodeVariant, then in Arc
            var root = ASTNode(BinaryOpNode(
                left = left,
                operator = op_tok^,
                right = right
            ))
            return (ASTNode(root^), cacheable and rc)
        return (left, cacheable)

    def _parse_additive(mut self) -> Self.ParseResult:
        var left: ASTNode
        var cacheable: Bool
        (left, cacheable) = self._parse_multiplicative()
        while True:
            ref t = self._current()
            var op_str = self._token_text(t)
            if t.type == Token.OPERATOR and (op_str == "+" or op_str == "-"):
                var op_tok = self._current().copy()
                self._advance()
                var right: ASTNode
                var rc: Bool
                (right, rc) = self._parse_multiplicative()

                # Wrap the BinaryOpNode in ASTNodeVariant, then in Arc
                left = ASTNode(BinaryOpNode(
                    left = left,
                    operator = op_tok^,
                    right = right
                ))
                cacheable = cacheable and rc
            else:
                break
        return (left, cacheable)

    def _parse_multiplicative(mut self) -> Self.ParseResult:
        var left: ASTNode
        var cacheable: Bool
        (left, cacheable) = self._parse_unary()
        while True:
            ref t = self._current()
            if t.type == Token.SLASH:
                var op_tok = self._current().copy()
                self._expect(Token.SLASH)
                (path, rc) = self._parse_path(is_absolute=False, first_step=None)
                left = ASTNode(BinaryOpNode(
                    left = left,
                    operator = op_tok^,
                    right = ASTNode(path^)
                ))
                cacheable = cacheable and rc
            elif t.type == Token.OPERATOR and self._token_text(t) == "*":
                var op_tok = self._current().copy()
                self._advance()
                var right: ASTNode
                var rc2: Bool
                (right, rc2) = self._parse_unary()
                var root = ASTNode(BinaryOpNode(
                    left = left,
                    operator = op_tok^,
                    right = right
                ))
                left = ASTNode(root^)
                cacheable = cacheable and rc2
            else:
                break
        return (left, cacheable)

    def _parse_unary(mut self) -> Self.ParseResult:
        ref t = self._current()
        if t.type == Token.OPERATOR and self._token_text(t) == "-":
            var op_tok = self._current().copy()
            self._advance()
            var operand: ASTNode
            var _c: Bool
            (operand, _c) = self._parse_unary()
            var zero = ASTNode(ASTNodeVariant(LiteralNode(value = Token(type=Token.NUMBER, start=0, length=1, line=1))))
            var root = ASTNode(BinaryOpNode(
                left = zero,
                operator = op_tok^,
                right = operand
            ))
            return (ASTNode(root^), False)
        if t.type == Token.OPERATOR and self._token_text(t) == "+":
            self._advance()
            return self._parse_unary()
        if self._is_keyword("not"):
            var op_tok = self._current().copy()
            self._advance()
            self._expect(Token.PAREN_OPEN)
            var operand2: ASTNode
            var _c2: Bool
            (operand2, _c2) = self._parse_expression()
            self._expect(Token.PAREN_CLOSE)
            var not_args = List[Arc[ASTNodeVariant]]()
            not_args.append(operand2)
            var v = ASTNodeVariant(FunctionCallNode(name = op_tok^, args = not_args^))
            return (ASTNode(v^), False)
        return self._parse_primary()

    def _parse_primary(mut self) -> Self.ParseResult:
        ref t = self._current()

        def _literal_node(value: Token, cacheable: Bool) -> Self.ParseResult:
            return ( ASTNode(ASTNodeVariant(LiteralNode(value = value.copy()))), cacheable )

        if t.type == Token.STRING:
            var tok = self._consume(Token.STRING)
            return _literal_node(tok^, True )
        if t.type == Token.NUMBER or t.type == Token.FLOAT_NUMBER:
            var tok = self._consume(t.type)
            return _literal_node(tok^, True)
        if t.type == Token.IDENTIFIER:
            if self._is_keyword("true"):
                var tok = self._current().copy()
                self._advance()
                return _literal_node(tok^, True)
            if self._is_keyword("false"):
                var tok = self._current().copy()
                self._advance()
                return _literal_node(tok^, True)
            # function call vs path (peek next token)
            if self._peek_next() == Token.PAREN_OPEN:
                return self._parse_function_call()
            ( path, cacheable ) = self._parse_path(is_absolute=False, first_step=None)
            return ( ASTNode(path^), cacheable )
        if t.type == Token.DOT or t.type == Token.DOTDOT or t.type == Token.SLASH:
            var is_absolute = t.type == Token.SLASH
            var first_step: Optional[Token] = None
            if t.type == Token.DOT or t.type == Token.DOTDOT:
                first_step = Optional(self._current().copy())
            self._advance()
            ( path, cacheable ) = self._parse_path(is_absolute=is_absolute, first_step=first_step)
            return ( ASTNode(path^), cacheable )
        if t.type == Token.PAREN_OPEN:
            self._advance()
            var expr: ASTNode
            var cacheable: Bool
            (expr, cacheable) = self._parse_expression()
            self._expect(Token.PAREN_CLOSE)
            return (expr, cacheable)
        raise Error("Unexpected token in primary: " + self._token_text(t))

    def _parse_function_call(mut self) -> Self.ParseResult:
        var name = self._current().copy()
        self._advance()
        self._expect(Token.PAREN_OPEN)
        var args = List[Arc[ASTNodeVariant]]()
        while self._currentType() != Token.PAREN_CLOSE:
            var node: ASTNode
            var _c: Bool
            (node, _c) = self._parse_expression()
            args.append(node)
            if self._currentType() == Token.PAREN_CLOSE:
                break
            self._expect(Token.COMMA)
        self._expect(Token.PAREN_CLOSE)
        var v = ASTNodeVariant(FunctionCallNode(name = name^, args = args^))
        return ( ASTNode(v^), False )

    def _parse_path(
        mut self,
        is_absolute: Bool,
        first_step: Optional[Token] = None,
        allow_predicate: Bool = True,
    ) -> Tuple[Arc[PathNode], Bool]:
        var segments = List[Arc[PathSegment]]()
        var cacheable = is_absolute
        var no_predicate = Optional[Arc[ASTNodeVariant]]()

        if first_step:
            var seg = PathSegment(step = first_step.value().copy(), predicate = no_predicate)
            segments.append(Arc[PathSegment](seg^))
            if self._currentType() == Token.SLASH:
                self._advance()
            else:
                var p = PathNode(segments = segments^, is_absolute = is_absolute, is_cacheable = cacheable)
                return (Arc[PathNode](p^), cacheable)

        while True:
            var tt = self._currentType()
            if tt != Token.DOT and tt != Token.DOTDOT and tt != Token.IDENTIFIER:
                break
            var consumed = self._consume(tt)
            var seg = PathSegment(step = consumed.copy(), predicate = no_predicate)
            segments.append(Arc[PathSegment](seg^))
            if self._currentType() != Token.SLASH:
                break
            self._advance()

        var p = PathNode(segments = segments^, is_absolute = is_absolute, is_cacheable = cacheable)
        return (Arc[PathNode](p^), cacheable)

