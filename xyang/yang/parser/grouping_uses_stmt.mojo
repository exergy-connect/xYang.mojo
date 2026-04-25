from std.memory import ArcPointer
from xyang.ast import (
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangLeafList,
    YangAnydata,
    YangAnyxml,
    YangGrouping,
)
from xyang.yang.parser.yang_token import YangToken
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer


def parse_grouping_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    parser._expect(YangToken.GROUPING)
    var name = parser._consume_name()

    var leaves = List[Arc[YangLeaf]]()
    var leaf_lists = List[Arc[YangLeafList]]()
    var anydatas = List[Arc[YangAnydata]]()
    var anyxmls = List[Arc[YangAnyxml]]()
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.LEAF:
                var leaf = parser._parse_leaf_statement()
                leaves.append(Arc[YangLeaf](leaf^))
            elif stmt == YangToken.LEAF_LIST:
                var leaf_list = parser._parse_leaf_list_statement()
                leaf_lists.append(Arc[YangLeafList](leaf_list^))
            elif stmt == YangToken.ANYDATA:
                var ad = parser._parse_anydata_statement()
                anydatas.append(Arc[YangAnydata](ad^))
            elif stmt == YangToken.ANYXML:
                var ax = parser._parse_anyxml_statement()
                anyxmls.append(Arc[YangAnyxml](ax^))
            elif stmt == YangToken.CONTAINER:
                var child_container = parser._parse_container_statement()
                containers.append(Arc[YangContainer](child_container^))
            elif stmt == YangToken.LIST:
                var child_list = parser._parse_list_statement()
                lists.append(Arc[YangList](child_list^))
            elif stmt == YangToken.CHOICE:
                var choice = parser._parse_choice_statement()
                choices.append(Arc[YangChoice](choice^))
            elif stmt == YangToken.USES:
                parser._parse_uses_statement(
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                    choices,
                )
            elif stmt == YangToken.AUGMENT:
                parser._parse_relative_augment_statement(
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                    choices,
                )
            elif stmt == YangToken.DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)

    var children = List[YangGrouping.ChildStatement]()
    for i in range(len(leaves)):
        children.append(YangGrouping.ChildStatement(leaves[i].copy()))
    for i in range(len(leaf_lists)):
        children.append(YangGrouping.ChildStatement(leaf_lists[i].copy()))
    for i in range(len(anydatas)):
        children.append(YangGrouping.ChildStatement(anydatas[i].copy()))
    for i in range(len(anyxmls)):
        children.append(YangGrouping.ChildStatement(anyxmls[i].copy()))
    for i in range(len(containers)):
        children.append(YangGrouping.ChildStatement(containers[i].copy()))
    for i in range(len(lists)):
        children.append(YangGrouping.ChildStatement(lists[i].copy()))
    for i in range(len(choices)):
        children.append(YangGrouping.ChildStatement(choices[i].copy()))

    parser._store_grouping(
        YangGrouping(
            name,
            children^,
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
    parser._expect(YangToken.USES)
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
    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.IF_FEATURE:
                parser._parse_if_feature_statement()
            elif stmt == YangToken.REFINE:
                parser._parse_refine_statement(
                    leaves,
                    leaf_lists,
                    anydatas,
                    anyxmls,
                    containers,
                    lists,
                    choices,
                )
            elif stmt == YangToken.AUGMENT:
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
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)


def parse_if_feature_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    parser._expect(YangToken.IF_FEATURE)
    _ = parser._consume_argument_value()
    parser._skip_if(YangToken.SEMICOLON)
