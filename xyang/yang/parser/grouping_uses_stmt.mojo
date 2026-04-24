from std.memory import ArcPointer
from xyang.ast import (
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangLeafList,
    YangAnydata,
    YangAnyxml,
)
from xyang.yang.tokens import (
    YANG_STMT_DESCRIPTION,
    YANG_STMT_GROUPING,
    YANG_STMT_LEAF,
    YANG_STMT_LEAF_LIST,
    YANG_STMT_ANYDATA,
    YANG_STMT_ANYXML,
    YANG_STMT_CONTAINER,
    YANG_STMT_LIST,
    YANG_STMT_CHOICE,
    YANG_STMT_USES,
    YANG_STMT_AUGMENT,
    YANG_STMT_IF_FEATURE,
    YANG_STMT_REFINE,
)
from xyang.yang.parser.types import ParsedGrouping
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer


def parse_grouping_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    parser._expect(YANG_STMT_GROUPING)
    var name = parser._consume_name()

    var leaves = List[Arc[YangLeaf]]()
    var leaf_lists = List[Arc[YangLeafList]]()
    var anydatas = List[Arc[YangAnydata]]()
    var anyxmls = List[Arc[YangAnyxml]]()
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_LEAF:
                var leaf = parser._parse_leaf_statement()
                leaves.append(Arc[YangLeaf](leaf^))
            elif stmt == YANG_STMT_LEAF_LIST:
                var leaf_list = parser._parse_leaf_list_statement()
                leaf_lists.append(Arc[YangLeafList](leaf_list^))
            elif stmt == YANG_STMT_ANYDATA:
                var ad = parser._parse_anydata_statement()
                anydatas.append(Arc[YangAnydata](ad^))
            elif stmt == YANG_STMT_ANYXML:
                var ax = parser._parse_anyxml_statement()
                anyxmls.append(Arc[YangAnyxml](ax^))
            elif stmt == YANG_STMT_CONTAINER:
                var child_container = parser._parse_container_statement()
                containers.append(Arc[YangContainer](child_container^))
            elif stmt == YANG_STMT_LIST:
                var child_list = parser._parse_list_statement()
                lists.append(Arc[YangList](child_list^))
            elif stmt == YANG_STMT_CHOICE:
                var choice = parser._parse_choice_statement()
                choices.append(Arc[YangChoice](choice^))
            elif stmt == YANG_STMT_USES:
                parser._parse_uses_statement(
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                    choices,
                )
            elif stmt == YANG_STMT_AUGMENT:
                parser._parse_relative_augment_statement(
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                    choices,
                )
            elif stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(";")
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    parser._store_grouping(
        ParsedGrouping(
            name,
            leaves^,
            leaf_lists^,
            anydatas^,
            anyxmls^,
            containers^,
            lists^,
            choices^,
        ),
    )


def parse_uses_statement_impl[ParserT: ParserContract](
    mut parser: ParserT,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut anydatas: List[Arc[YangAnydata]],
    mut anyxmls: List[Arc[YangAnyxml]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) raises:
    parser._expect(YANG_STMT_USES)
    var grouping_name = parser._consume_name()
    parser._append_grouping_nodes_by_name(
        grouping_name,
        leaves,
        leaf_lists,
        anydatas,
        anyxmls,
        containers,
        lists,
        choices,
    )
    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_IF_FEATURE:
                parser._parse_if_feature_statement()
            elif stmt == YANG_STMT_REFINE:
                parser._parse_refine_statement(
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                    choices,
                )
            elif stmt == YANG_STMT_AUGMENT:
                parser._parse_relative_augment_statement(
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                    choices,
                )
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")


def parse_if_feature_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    parser._expect(YANG_STMT_IF_FEATURE)
    _ = parser._consume_argument_value()
    parser._skip_if(";")
