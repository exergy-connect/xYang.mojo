from std.memory import ArcPointer
from xyang.ast import YangModule, YangContainer
from xyang.yang.parser.yang_token import YangToken
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer


def parse_module_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangModule:
    parser._expect(YangToken.MODULE)
    var module_name = parser._consume_name()
    parser._expect(YangToken.LBRACE)

    var namespace = ""
    var prefix = ""
    var description = ""
    var revisions = List[String]()
    var organization = ""
    var contact = ""
    var top_containers = List[Arc[YangContainer]]()

    ## Pre-resolve top-level groupings so forward `uses` can be expanded regardless of declaration order.
    parser._prime_groupings_for_current_module_body()

    while parser._has_more() and parser._peek() != YangToken.RBRACE:
        var stmt = parser._peek()
        if stmt == YangToken.NAMESPACE:
            parser._consume()
            namespace = parser._consume_argument_value()
            parser._skip_if(YangToken.SEMICOLON)
        elif stmt == YangToken.PREFIX:
            parser._consume()
            prefix = parser._consume_argument_value()
            parser._skip_if(YangToken.SEMICOLON)
        elif stmt == YangToken.DESCRIPTION:
            parser._consume()
            description = parser._consume_argument_value()
            parser._skip_if(YangToken.SEMICOLON)
        elif stmt == YangToken.REVISION:
            parser._consume()
            revisions.append(parser._consume_argument_value())
            if parser._consume_if(YangToken.LBRACE):
                parser._skip_block_body()
            parser._skip_if(YangToken.SEMICOLON)
        elif stmt == YangToken.ORGANIZATION:
            parser._consume()
            organization = parser._consume_argument_value()
            parser._skip_if(YangToken.SEMICOLON)
        elif stmt == YangToken.CONTACT:
            parser._consume()
            contact = parser._consume_argument_value()
            parser._skip_if(YangToken.SEMICOLON)
        elif stmt == YangToken.CONTAINER:
            var c = parser._parse_container_statement()
            top_containers.append(Arc[YangContainer](c^))
        elif stmt == YangToken.GROUPING:
            # Groupings were already captured by the pre-pass above; parse again for robust
            # statement consumption, but ignore the expected replay duplicate-store error.
            try:
                parser._parse_grouping_statement()
            except e:
                var msg = String(e)
                if not _is_duplicate_grouping_error(msg):
                    raise e^
        elif stmt == YangToken.AUGMENT:
            parser._parse_module_augment_statement(top_containers)
        else:
            parser._skip_statement()

    parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)
    parser._apply_pending_module_augments(top_containers)

    return YangModule(
        name = module_name,
        namespace = namespace,
        prefix = prefix,
        description = description^,
        revisions = revisions^,
        organization = organization^,
        contact = contact^,
        top_level_containers = top_containers^,
    )


def _is_duplicate_grouping_error(message: String) -> Bool:
    return len(message.split("Duplicate grouping '")) > 1
