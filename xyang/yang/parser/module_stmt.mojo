from std.memory import ArcPointer
from xyang.ast import (
    YangModule,
    YangContainer,
    YangRevisionStmt,
    YangFeatureStmt,
    YangModuleStatement,
    YangUnknownStatement,
)
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
            var c_arc = Arc[YangContainer](c^)
            top_containers.append(c_arc.copy())
            parser._record_module_statement(YangModuleStatement(c_arc))
        elif stmt == YangToken.GROUPING:
            var grouping_name = parser._peek_value_n(1)
            # Groupings were already captured by the pre-pass above; parse again for robust
            # statement consumption, but ignore the expected replay duplicate-store error.
            try:
                parser._parse_grouping_statement()
            except e:
                var msg = String(e)
                if not _is_duplicate_grouping_error(msg):
                    raise e^
            var grouping_opt = parser._get_groupings_snapshot().get(grouping_name)
            if grouping_opt:
                parser._record_module_statement(
                    YangModuleStatement(grouping_opt.value().copy()),
                )
        elif stmt == YangToken.TYPEDEF:
            var typedef_name = parser._peek_value_n(1)
            parser._parse_typedef_statement()
            var typedef_stmt = parser._get_typedef_statements_snapshot().get(typedef_name)
            if typedef_stmt:
                parser._record_module_statement(
                    YangModuleStatement(typedef_stmt.value().copy()),
                )
        elif stmt == YangToken.AUGMENT:
            parser._parse_module_augment_statement(top_containers)
        elif parser._peek_prefixed_extension():
            parser._skip_prefixed_extension_statement()
        else:
            var skipped_keyword = parser._peek_value()
            parser._record_module_statement(
                YangModuleStatement(
                    Arc[YangUnknownStatement](
                        YangUnknownStatement(
                            keyword = skipped_keyword,
                            argument = "",
                            has_argument = False,
                        ),
                    ),
                ),
            )
            parser._skip_statement()

    parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)
    parser._apply_pending_module_augments(top_containers)
    var revision_statements = List[Arc[YangRevisionStmt]]()
    for i in range(len(revisions)):
        revision_statements.append(
            Arc[YangRevisionStmt](YangRevisionStmt(date = revisions[i], description = "")),
        )

    return YangModule(
        name = module_name,
        namespace = namespace,
        prefix = prefix,
        description = description^,
        yang_version = "1.1",
        belongs_to_module = "",
        revisions = revisions^,
        revision_statements = revision_statements^,
        organization = organization^,
        contact = contact^,
        typedefs = parser._get_typedef_statements_snapshot(),
        identities = parser._identities_snapshot(),
        groupings = parser._get_groupings_snapshot(),
        features = List[Arc[YangFeatureStmt]](),
        feature_if_features = parser._feature_if_features_snapshot(),
        import_prefixes = parser._import_prefixes_snapshot(),
        extensions = parser._extensions_snapshot(),
        statements = parser._module_statements_snapshot(),
        top_level_containers = top_containers^,
    )


def _is_duplicate_grouping_error(message: String) -> Bool:
    return len(message.split("Duplicate grouping '")) > 1
