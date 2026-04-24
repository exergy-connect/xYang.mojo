from std.memory import ArcPointer
from xyang.ast import YangModule, YangContainer
from xyang.yang.parser.yang_token import (
    YANG_STMT_MODULE,
    YANG_STMT_NAMESPACE,
    YANG_STMT_PREFIX,
    YANG_STMT_DESCRIPTION,
    YANG_STMT_REVISION,
    YANG_STMT_ORGANIZATION,
    YANG_STMT_CONTACT,
    YANG_STMT_CONTAINER,
    YANG_STMT_GROUPING,
    YANG_STMT_AUGMENT,
)
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer


def parse_module_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangModule:
    parser._expect(YANG_STMT_MODULE)
    var module_name = parser._consume_name()
    parser._expect("{")

    var namespace = ""
    var prefix = ""
    var description = ""
    var revisions = List[String]()
    var organization = ""
    var contact = ""
    var top_containers = List[Arc[YangContainer]]()

    while parser._has_more() and parser._peek() != "}":
        var stmt = parser._peek()
        if stmt == YANG_STMT_NAMESPACE:
            parser._consume()
            namespace = parser._consume_argument_value()
            parser._skip_if(";")
        elif stmt == YANG_STMT_PREFIX:
            parser._consume()
            prefix = parser._consume_argument_value()
            parser._skip_if(";")
        elif stmt == YANG_STMT_DESCRIPTION:
            parser._consume()
            description = parser._consume_argument_value()
            parser._skip_if(";")
        elif stmt == YANG_STMT_REVISION:
            parser._consume()
            revisions.append(parser._consume_argument_value())
            if parser._consume_if("{"):
                parser._skip_block_body()
            parser._skip_if(";")
        elif stmt == YANG_STMT_ORGANIZATION:
            parser._consume()
            organization = parser._consume_argument_value()
            parser._skip_if(";")
        elif stmt == YANG_STMT_CONTACT:
            parser._consume()
            contact = parser._consume_argument_value()
            parser._skip_if(";")
        elif stmt == YANG_STMT_CONTAINER:
            var c = parser._parse_container_statement()
            top_containers.append(Arc[YangContainer](c^))
        elif stmt == YANG_STMT_GROUPING:
            parser._parse_grouping_statement()
        elif stmt == YANG_STMT_AUGMENT:
            parser._parse_module_augment_statement(top_containers)
        else:
            parser._skip_statement()

    parser._expect("}")
    parser._skip_if(";")
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
