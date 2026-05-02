## YANG text → `YangConstruct` parsing (lexer-driven).

from std.memory import ArcPointer

from .construct import YangConstruct
from .lexer import AstLexer, AstToken


comptime Arc = ArcPointer


def is_name_token(tok: AstToken) -> Bool:
    return tok.type == AstToken.IDENTIFIER

def parse_module[
    origin: ImmutOrigin
](mut lexer: AstLexer[origin]) raises -> YangConstruct:
    var tok = lexer.next_token()
    if tok.type == AstToken.EOF:
        raise Error(
            "line "
            + String(lexer.line)
            + ": Expected module statement, got EOF"
        )
    if not is_name_token(tok):
        raise Error(
            "Expected module statement keyword, got `"
            + tok.text(lexer.input)
            + "` at line "
            + String(tok.line)
        )

    var module = parse_statement_after_keyword(
        lexer, tok.text(lexer.input), tok.line
    )
    if module.keyword != "module":
        raise Error(
            "line "
            + String(module.line)
            + ": Expected module statement, got `"
            + module.keyword
            + "`"
        )

    tok = lexer.next_token()
    if tok.type != AstToken.EOF:
        raise Error(
            "Expected EOF after module statement, got `"
            + tok.text(lexer.input)
            + "` at line "
            + String(tok.line)
        )
    return module^

def parse_block[
    origin: ImmutOrigin
](mut lexer: AstLexer[origin]) raises -> YangConstruct.StatementList:
    var children = YangConstruct.StatementList()
    while True:
        var tok = lexer.next_token()
        if tok.type == AstToken.EOF:
            raise Error(
                "line "
                + String(lexer.line)
                + ": Unexpected end of input while parsing statement block"
            )
        if tok.type == AstToken.RBRACE:
            return children^
        if not is_name_token(tok):
            raise Error(
                "Expected statement keyword, got `"
                + tok.text(lexer.input)
                + "` at line "
                + String(tok.line)
            )
        children.append(
            Arc[YangConstruct](
                parse_statement_after_keyword(
                    lexer, tok.text(lexer.input), tok.line
                ),
            ),
        )


def parse_statement_after_keyword[
    origin: ImmutOrigin
](
    mut lexer: AstLexer[origin], keyword: String, line: Int
) raises -> YangConstruct:
    var statement = YangConstruct(keyword, line)
    var tok = lexer.next_token()

    if tok.type == AstToken.SEMICOLON:
        return statement^
    if tok.type != AstToken.LBRACE:
        var terminator = parse_argument(lexer, tok, statement)
        if terminator == AstToken.SEMICOLON:
            return statement^
        if terminator != AstToken.LBRACE:
            raise Error(
                "line "
                + String(statement.line)
                + ": Expected `;` or `{` after statement argument"
            )
    statement.children = parse_block(lexer)
    return statement^


def parse_argument[
    origin: ImmutOrigin
](
    mut lexer: AstLexer[origin],
    first_token: AstToken,
    mut statement: YangConstruct,
) raises -> AstToken.Type:
    var result = first_token.text(lexer.input, strip_quotes=True)

    while True:
        var tok = lexer.next_token()
        if tok.type == AstToken.SEMICOLON or tok.type == AstToken.LBRACE:
            statement.set_raw_argument(result^)
            return tok.type
        if tok.type == AstToken.EOF or tok.type == AstToken.RBRACE:
            raise Error(
                "line "
                + String(statement.line)
                + ": Unexpected end of statement argument"
            )
        if tok.type != AstToken.PLUS:
            result += " "
            result += tok.text(lexer.input, strip_quotes=True)

