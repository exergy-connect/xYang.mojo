from std.collections import Dict
from std.memory import ArcPointer, UnsafePointer
import xyang.ast as ast
from xyang.xpath.path_parser import local_names_from_slashed_path_parts
from xyang.yang.parser.must_stmt import parse_must
from xyang.yang.parser.yang_token import YangToken
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer


struct RefineParser[ParserT: ParserContract](Movable):
    ## Token → refine-substatement handler (built once per parser type, e.g. `_YangParser`).
    ## Exposed on `ParserContract` via `_refine_substatements` for `parse_refine`.
    var substatements: Dict[YangToken.Type, ast.ParserMethod[Self.ParserT]]

    def __init__(out self):
        self.substatements = Dict[YangToken.Type, ast.ParserMethod[Self.ParserT]]()
        self.substatements[YangToken.MUST] = parse_must[Self.ParserT]
        self.substatements[YangToken.DESCRIPTION] = parse_description[Self.ParserT]
        self.substatements[YangToken.MIN_ELEMENTS] = parse_min_elements[Self.ParserT]
        self.substatements[YangToken.MAX_ELEMENTS] = parse_max_elements[Self.ParserT]
        self.substatements[YangToken.ORDERED_BY] = parse_ordered_by[Self.ParserT]
        self.substatements[YangToken.MANDATORY] = parse_mandatory[Self.ParserT]
        self.substatements[YangToken.DEFAULT] = parse_default[Self.ParserT]
        self.substatements[YangToken.IF_FEATURE] = parse_if_feature_stmt[Self.ParserT]
        self.substatements[YangToken.TYPE] = parse_type[Self.ParserT]


def _join_slashed_path_parts(read parts: List[String]) -> String:
    var out = String("")
    for i in range(len(parts)):
        if i > 0:
            out += "/"
        out += parts[i]
    return out^


def _consume_refine_slashed_path_parts[ParserT: ParserContract](
    mut parser: ParserT
) raises -> List[String]:
    if not parser._has_more():
        parser._error("refine requires a path")
    var first = parser._consume_value()
    if not parser._has_more() or parser._peek() != YangToken.SLASH:
        var value = first
        while parser._has_more() and parser._peek() == YangToken.PLUS:
            parser._consume()
            value += parser._consume_value()
        var one_part = List[String]()
        one_part.append(value^)
        return one_part^
    var parts = List[String]()
    parts.append(first^)
    while parser._has_more() and parser._peek() == YangToken.SLASH:
        parser._consume()
        if not parser._has_more():
            parser._error("trailing '/' in refine path")
        parts.append(parser._consume_value())
    return parts^


def _stub_unknown(keyword: String) -> ast.YangAstNode:
    return ast.YangAstNode(
        ast.YangUnknownStatement(
            keyword = keyword,
            argument = "",
            has_argument = False,
        )
    )


def _stub_yang_type() -> ast.YangAstNode:
    return ast.YangAstNode(
        ast.YangType(
            name = "",
            constraints = ast.YangType.Constraints(
                ast.YangTypeTypedef(
                    resolved = UnsafePointer[
                        ast.YangTypedefStmt, MutExternalOrigin
                    ](),
                )
            ),
        )
    )


def parse_description[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAstNode:
    parser._skip_statement()
    return _stub_unknown("description")


def parse_min_elements[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAstNode:
    parser._skip_statement()
    return _stub_unknown("min-elements")


def parse_max_elements[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAstNode:
    parser._skip_statement()
    return _stub_unknown("max-elements")


def parse_ordered_by[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAstNode:
    parser._skip_statement()
    return _stub_unknown("ordered-by")


def parse_mandatory[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAstNode:
    parser._skip_statement()
    return _stub_unknown("mandatory")


def parse_default[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAstNode:
    parser._skip_statement()
    return _stub_unknown("default")


def parse_if_feature_stmt[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAstNode:
    parser._skip_statement()
    return ast.YangAstNode(
        ast.YangFeatureStmt(
            name = "",
            if_features = List[String](),
            description = "",
        )
    )


def parse_type[ParserT: ParserContract](mut parser: ParserT) raises -> ast.YangAstNode:
    parser._skip_statement()
    return _stub_yang_type()


def parse_refine[ParserT: ParserContract](mut parser: ParserT) raises -> ast.YangAstNode:
    var substatement_handlers = parser._refine_substatements()

    parser._expect(YangToken.REFINE)
    var path_parts = _consume_refine_slashed_path_parts(parser)
    var target_path = _join_slashed_path_parts(path_parts)
    var segments = local_names_from_slashed_path_parts(path_parts^)
    if len(segments) == 0:
        parser._error("refine requires a descendant schema-node identifier")

    var refine = ast.YangRefineStmt(
        target_path = target_path^,
        mandatory = Optional[Bool](),
        min_elements = Optional[Int](),
        max_elements = Optional[Int](),
        presence = Optional[String](),
        default_values = List[String](),
        description = Optional[String](),
        if_features = List[String](),
        must = ast.YangMustStatements(must_statements = List[Arc[ast.YangMust]]()),
        when = Optional[ast.YangWhen](),
    )

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var keyword = parser._peek()
            if keyword in substatement_handlers:
                _ = substatement_handlers[keyword](parser)
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)
    return ast.YangAstNode(refine^)
