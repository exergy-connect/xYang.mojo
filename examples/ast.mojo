## Recursive YANG construct tree.
##
## This is the intermediate representation layer between tokens and typed YANG
## models: it preserves the nested construct shape without deciding which
## constructs are valid in each context.
##
##   pixi run mojo examples/ast.mojo

from std.memory import ArcPointer

from ast_lexer import AstLexer, AstToken


comptime Arc = ArcPointer


@fieldwise_init
struct YangConstruct(ImplicitlyDestructible, Movable, Writable):
    comptime StatementList = List[Arc[YangConstruct]]

    var keyword: String
    var argument: Optional[String]
    var children: Self.StatementList

    def __init__(out self, keyword: String):
        self.keyword = keyword
        self.argument = Optional[String]()
        self.children = Self.StatementList()

    def __str__(ref self) -> String:
        return self.format(0)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.format(0))

    def format(ref self, indent: Int) -> String:
        var result = String()
        for _ in range(indent):
            result += "  "
        result += self.keyword
        if self.argument:
            result += " "
            result += repr(self.argument.value())
        if len(self.children) == 0:
            result += ";\n"
            return result

        result += " {\n"
        for child in self.children:
            result += child[].format(indent + 1)
        for _ in range(indent):
            result += "  "
        result += "}\n"
        return result


def is_name_token(tok: AstToken) -> Bool:
    return tok.type == AstToken.ATOM or tok.type == AstToken.QNAME


def parse_document[
    origin: ImmutOrigin
](mut lexer: AstLexer[origin]) raises -> YangConstruct.StatementList:
    var statements = YangConstruct.StatementList()
    while True:
        var tok = lexer.next_token()
        if tok.type == AstToken.EOF:
            return statements^
        if not is_name_token(tok):
            raise Error(
                "Expected statement keyword, got `"
                + tok.text(lexer.input)
                + "`"
            )
        statements.append(
            Arc[YangConstruct](
                parse_statement_after_keyword(lexer, tok.text(lexer.input)),
            ),
        )


def parse_block[
    origin: ImmutOrigin
](mut lexer: AstLexer[origin]) raises -> YangConstruct.StatementList:
    var children = YangConstruct.StatementList()
    while True:
        var tok = lexer.next_token()
        if tok.type == AstToken.EOF:
            raise Error("Unexpected end of input while parsing statement block")
        if tok.type == AstToken.RBRACE:
            return children^
        if not is_name_token(tok):
            raise Error(
                "Expected statement keyword, got `"
                + tok.text(lexer.input)
                + "`"
            )
        children.append(
            Arc[YangConstruct](
                parse_statement_after_keyword(lexer, tok.text(lexer.input)),
            ),
        )


def parse_statement_after_keyword[
    origin: ImmutOrigin
](mut lexer: AstLexer[origin], keyword: String) raises -> YangConstruct:
    var statement = YangConstruct(keyword)
    var tok = lexer.next_token()

    if tok.type == AstToken.SEMICOLON:
        return statement^

    if tok.type == AstToken.LBRACE:
        statement.children = parse_block(lexer)
        return statement^

    var terminator = parse_argument(lexer, tok, statement)
    if terminator == AstToken.SEMICOLON:
        return statement^
    if terminator == AstToken.LBRACE:
        statement.children = parse_block(lexer)
        return statement^

    raise Error("Expected `;` or `{` after statement argument")


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
            statement.argument = Optional[String](result^)
            return tok.type
        if tok.type == AstToken.EOF or tok.type == AstToken.RBRACE:
            raise Error("Unexpected end of statement argument")
        if tok.type != AstToken.PLUS:
            result += " "
            result += tok.text(lexer.input, strip_quotes=True)


def main() raises:
    var source: String
    with open("examples/meta-model.yang", "r") as f:
        source = f.read()
    var lexer = AstLexer(source.as_bytes())
    var statements = parse_document(lexer)
    for statement in statements:
        print(statement[])
