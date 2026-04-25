from std.memory import ArcPointer
from xyang.ast import (
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangLeafList,
    YangAnydata,
    YangAnyxml,
    YangType,
    YangMust,
    YangWhen,
)
from xyang.yang.parser.yang_token import YangToken
from xyang.yang.parser.parsed_augment import ParsedAugment
from xyang.yang.parser.parser_contract import ParserContract
from xyang.yang.parser.clone_utils import (
    ident_local_name_impl,
    split_schema_path_impl,
    clone_must_impl,
    clone_when_impl,
    clone_yang_type_impl,
    clone_leaf_arc_impl,
    clone_leaf_list_arc_impl,
    clone_choice_arc_impl,
    clone_anydata_arc_impl,
    clone_anyxml_arc_impl,
    clone_container_arc_impl,
    clone_list_arc_impl,
)

comptime Arc = ArcPointer


def parse_refine_statement_impl[ParserT: ParserContract](
    mut parser: ParserT,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut anydatas: List[Arc[YangAnydata]],
    mut anyxmls: List[Arc[YangAnyxml]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) raises:
    _ = anydatas
    _ = anyxmls
    parser._expect(YangToken.REFINE)
    var refine_path = parser._consume_argument_value()
    var segments = split_schema_path_impl(refine_path)
    if len(segments) == 0:
        parser._error("refine requires a descendant schema-node identifier")
        parser._skip_statement_tail()
        return

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.DESCRIPTION:
                parser._consume()
                var desc = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_set_description_at_path_impl(
                    segments,
                    0,
                    desc,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                    choices,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.MANDATORY:
                parser._consume()
                var mandatory = parser._parse_boolean_value()
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_set_mandatory_at_path_impl(
                    segments,
                    0,
                    mandatory,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                    choices,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.DEFAULT:
                parser._consume()
                var default_value = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_set_default_at_path_impl(
                    segments,
                    0,
                    default_value,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                    choices,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.MUST:
                var must_stmt = parser._parse_must_statement()
                if not refine_add_must_at_path_impl(
                    segments,
                    0,
                    must_stmt,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                    choices,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.WHEN:
                var when_stmt = parser._parse_when_statement()
                if not refine_set_when_at_path_impl(
                    segments,
                    0,
                    when_stmt,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                    choices,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.TYPE:
                var type_stmt = parser._parse_type_statement()
                if not refine_set_type_at_path_impl(
                    segments,
                    0,
                    type_stmt,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                    choices,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.MIN_ELEMENTS:
                parser._consume()
                var min_el = parser._parse_non_negative_int("min-elements")
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_set_min_elements_at_path_impl(
                    segments,
                    0,
                    min_el,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.MAX_ELEMENTS:
                parser._consume()
                var max_el = parser._parse_non_negative_int("max-elements")
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_set_max_elements_at_path_impl(
                    segments,
                    0,
                    max_el,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.ORDERED_BY:
                parser._consume()
                var ordered_by = parser._parse_ordered_by_argument()
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_set_ordered_by_at_path_impl(
                    segments,
                    0,
                    ordered_by,
                    leaves,
                    leaf_lists,
                    containers,
                    lists,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.KEY:
                parser._consume()
                var key = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_set_key_at_path_impl(
                    segments,
                    0,
                    key,
                    containers,
                    lists,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.UNIQUE:
                parser._consume()
                var uarg = parser._consume_argument_value()
                var ucomp = parser._unique_components_from_argument(uarg)
                parser._skip_if(YangToken.SEMICOLON)
                if not refine_add_unique_at_path_impl(
                    segments,
                    0,
                    ucomp,
                    containers,
                    lists,
                ):
                    parser._error("Unknown refine target path '" + refine_path + "'")
            elif stmt == YangToken.IF_FEATURE:
                parser._parse_if_feature_statement()
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)


def parse_relative_augment_statement_impl[ParserT: ParserContract](
    mut parser: ParserT,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut anydatas: List[Arc[YangAnydata]],
    mut anyxmls: List[Arc[YangAnyxml]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) raises:
    var parsed = parse_augment_statement_body_impl(parser)
    if len(parsed.path) > 0 and String(parsed.path[byte=0 : 1]) == "/":
        parser._queue_pending_module_augment(parsed^)
        return
    if not apply_augment_to_path_impl(
        parsed.path,
        leaves,
        leaf_lists,
        anydatas,
        anyxmls,
        containers,
        lists,
        choices,
        parsed,
    ):
        parser._error("Unknown augment target path '" + parsed.path + "'")


def parse_module_augment_statement_impl[ParserT: ParserContract](
    mut parser: ParserT,
    mut top_containers: List[Arc[YangContainer]],
) raises:
    var parsed = parse_augment_statement_body_impl(parser)
    if len(parsed.path) > 0 and String(parsed.path[byte=0 : 1]) == "/":
        parser._queue_pending_module_augment(parsed^)
        return
    var root_leaves = List[Arc[YangLeaf]]()
    var root_leaf_lists = List[Arc[YangLeafList]]()
    var root_anydatas = List[Arc[YangAnydata]]()
    var root_anyxmls = List[Arc[YangAnyxml]]()
    var root_lists = List[Arc[YangList]]()
    var root_choices = List[Arc[YangChoice]]()
    if not apply_augment_to_path_impl(
        parsed.path,
        root_leaves,
        root_leaf_lists,
        root_anydatas,
        root_anyxmls,
        top_containers,
        root_lists,
        root_choices,
        parsed,
    ):
        parser._error("Unknown augment target path '" + parsed.path + "'")


def apply_pending_module_augments_impl(
    read pending_module_augments: List[Arc[ParsedAugment]],
    mut top_containers: List[Arc[YangContainer]],
) -> String:
    var root_leaves = List[Arc[YangLeaf]]()
    var root_leaf_lists = List[Arc[YangLeafList]]()
    var root_anydatas = List[Arc[YangAnydata]]()
    var root_anyxmls = List[Arc[YangAnyxml]]()
    var root_lists = List[Arc[YangList]]()
    var root_choices = List[Arc[YangChoice]]()
    for i in range(len(pending_module_augments)):
        var aug_arc = pending_module_augments[i].copy()
        ref aug = aug_arc[]
        if not apply_augment_to_path_impl(
            aug.path,
            root_leaves,
            root_leaf_lists,
            root_anydatas,
            root_anyxmls,
            top_containers,
            root_lists,
            root_choices,
            aug,
        ):
            return aug.path
    return ""


def parse_augment_statement_body_impl[ParserT: ParserContract](mut parser: ParserT) raises -> ParsedAugment:
    parser._expect(YangToken.AUGMENT)
    var target_path = parser._consume_argument_value()

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
            elif stmt == YangToken.IF_FEATURE:
                parser._parse_if_feature_statement()
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

    return ParsedAugment(
        target_path,
        leaves^,
        leaf_lists^,
        anydatas^,
        anyxmls^,
        containers^,
        lists^,
        choices^,
    )


def apply_augment_to_path_impl(
    path: String,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut anydatas: List[Arc[YangAnydata]],
    mut anyxmls: List[Arc[YangAnyxml]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
    read aug: ParsedAugment,
) -> Bool:
    var segments = split_schema_path_impl(path)
    if len(segments) == 0:
        return False
    return apply_augment_segments_impl(
        segments,
        0,
        leaves,
        leaf_lists,
        anydatas,
        anyxmls,
        containers,
        lists,
        choices,
        aug,
    )


def apply_augment_segments_impl(
    read segments: List[String],
    seg_idx: Int,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut anydatas: List[Arc[YangAnydata]],
    mut anyxmls: List[Arc[YangAnyxml]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
    read aug: ParsedAugment,
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(containers)):
            if ident_local_name_impl(containers[i][].name) == seg:
                for j in range(len(aug.leaves)):
                    containers[i][].leaves.append(clone_leaf_arc_impl(aug.leaves[j]))
                for j in range(len(aug.leaf_lists)):
                    containers[i][].leaf_lists.append(clone_leaf_list_arc_impl(aug.leaf_lists[j]))
                for j in range(len(aug.anydatas)):
                    containers[i][].anydatas.append(clone_anydata_arc_impl(aug.anydatas[j]))
                for j in range(len(aug.anyxmls)):
                    containers[i][].anyxmls.append(clone_anyxml_arc_impl(aug.anyxmls[j]))
                for j in range(len(aug.containers)):
                    containers[i][].containers.append(clone_container_arc_impl(aug.containers[j]))
                for j in range(len(aug.lists)):
                    containers[i][].lists.append(clone_list_arc_impl(aug.lists[j]))
                for j in range(len(aug.choices)):
                    containers[i][].choices.append(clone_choice_arc_impl(aug.choices[j]))
                applied = True
        for i in range(len(lists)):
            if ident_local_name_impl(lists[i][].name) == seg:
                for j in range(len(aug.leaves)):
                    lists[i][].leaves.append(clone_leaf_arc_impl(aug.leaves[j]))
                for j in range(len(aug.leaf_lists)):
                    lists[i][].leaf_lists.append(clone_leaf_list_arc_impl(aug.leaf_lists[j]))
                for j in range(len(aug.anydatas)):
                    lists[i][].anydatas.append(clone_anydata_arc_impl(aug.anydatas[j]))
                for j in range(len(aug.anyxmls)):
                    lists[i][].anyxmls.append(clone_anyxml_arc_impl(aug.anyxmls[j]))
                for j in range(len(aug.containers)):
                    lists[i][].containers.append(clone_container_arc_impl(aug.containers[j]))
                for j in range(len(aug.lists)):
                    lists[i][].lists.append(clone_list_arc_impl(aug.lists[j]))
                for j in range(len(aug.choices)):
                    lists[i][].choices.append(clone_choice_arc_impl(aug.choices[j]))
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if apply_augment_segments_impl(
                segments,
                seg_idx + 1,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].anydatas,
                containers[i][].anyxmls,
                containers[i][].containers,
                containers[i][].lists,
                containers[i][].choices,
                aug,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if apply_augment_segments_impl(
                segments,
                seg_idx + 1,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].anydatas,
                lists[i][].anyxmls,
                lists[i][].containers,
                lists[i][].lists,
                lists[i][].choices,
                aug,
            ):
                applied = True
    return applied


def refine_set_description_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    description: String,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if ident_local_name_impl(leaves[i][].name) == seg:
                # Leaf description is not modeled in the current AST; treat as recognized no-op.
                applied = True
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                # Leaf-list description is not modeled in the current AST; treat as recognized no-op.
                applied = True
        for i in range(len(containers)):
            if ident_local_name_impl(containers[i][].name) == seg:
                containers[i][].description = description
                applied = True
        for i in range(len(lists)):
            if ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].description = description
                applied = True
        for i in range(len(choices)):
            if ident_local_name_impl(choices[i][].name) == seg:
                # Choice/case descriptions are not modeled in the current AST; treat as recognized no-op.
                applied = True
            for j in range(len(choices[i][].cases)):
                if ident_local_name_impl(choices[i][].cases[j][].name) == seg:
                    applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_description_at_path_impl(
                segments,
                seg_idx + 1,
                description,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
                containers[i][].choices,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_description_at_path_impl(
                segments,
                seg_idx + 1,
                description,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
                lists[i][].choices,
            ):
                applied = True
    return applied


def refine_set_mandatory_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    mandatory: Bool,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].mandatory = mandatory
                applied = True
        for i in range(len(choices)):
            if ident_local_name_impl(choices[i][].name) == seg:
                choices[i][].mandatory = mandatory
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_mandatory_at_path_impl(
                segments,
                seg_idx + 1,
                mandatory,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
                containers[i][].choices,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_mandatory_at_path_impl(
                segments,
                seg_idx + 1,
                mandatory,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
                lists[i][].choices,
            ):
                applied = True
    return applied


def refine_set_default_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    default_value: String,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].default_value = default_value
                leaves[i][].has_default = True
                applied = True
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].default_values.append(default_value)
                applied = True
        for i in range(len(choices)):
            if ident_local_name_impl(choices[i][].name) == seg:
                choices[i][].default_case = default_value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_default_at_path_impl(
                segments,
                seg_idx + 1,
                default_value,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
                containers[i][].choices,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_default_at_path_impl(
                segments,
                seg_idx + 1,
                default_value,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
                lists[i][].choices,
            ):
                applied = True
    return applied


def refine_add_must_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read must_stmt: YangMust,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].must_statements.append(Arc[YangMust](clone_must_impl(must_stmt)))
                applied = True
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].must_statements.append(Arc[YangMust](clone_must_impl(must_stmt)))
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_add_must_at_path_impl(
                segments,
                seg_idx + 1,
                must_stmt,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
                containers[i][].choices,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_add_must_at_path_impl(
                segments,
                seg_idx + 1,
                must_stmt,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
                lists[i][].choices,
            ):
                applied = True
    return applied


def refine_set_when_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read when_stmt: YangWhen,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].when = Optional(clone_when_impl(when_stmt))
                applied = True
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].when = Optional(clone_when_impl(when_stmt))
                applied = True
        for i in range(len(choices)):
            if ident_local_name_impl(choices[i][].name) == seg:
                choices[i][].when = Optional(clone_when_impl(when_stmt))
                applied = True
            for j in range(len(choices[i][].cases)):
                if ident_local_name_impl(choices[i][].cases[j][].name) == seg:
                    choices[i][].cases[j][].when = Optional(clone_when_impl(when_stmt))
                    applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_when_at_path_impl(
                segments,
                seg_idx + 1,
                when_stmt,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
                containers[i][].choices,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_when_at_path_impl(
                segments,
                seg_idx + 1,
                when_stmt,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
                lists[i][].choices,
            ):
                applied = True
    return applied


def refine_set_type_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read type_stmt: YangType,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].type = clone_yang_type_impl(type_stmt)
                applied = True
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].type = clone_yang_type_impl(type_stmt)
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_type_at_path_impl(
                segments,
                seg_idx + 1,
                type_stmt,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
                containers[i][].choices,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_type_at_path_impl(
                segments,
                seg_idx + 1,
                type_stmt,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
                lists[i][].choices,
            ):
                applied = True
    return applied


def refine_set_min_elements_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    value: Int,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].min_elements = value
                applied = True
        for i in range(len(lists)):
            if ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].min_elements = value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_min_elements_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_min_elements_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
            ):
                applied = True
    return applied


def refine_set_max_elements_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    value: Int,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].max_elements = value
                applied = True
        for i in range(len(lists)):
            if ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].max_elements = value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_max_elements_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_max_elements_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
            ):
                applied = True
    return applied


def refine_set_ordered_by_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    value: String,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaf_lists)):
            if ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].ordered_by = value
                applied = True
        for i in range(len(lists)):
            if ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].ordered_by = value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_ordered_by_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                containers[i][].leaves,
                containers[i][].leaf_lists,
                containers[i][].containers,
                containers[i][].lists,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_ordered_by_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                lists[i][].leaves,
                lists[i][].leaf_lists,
                lists[i][].containers,
                lists[i][].lists,
            ):
                applied = True
    return applied


def refine_set_key_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    key: String,
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(lists)):
            if ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].key = key
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_key_at_path_impl(
                segments,
                seg_idx + 1,
                key,
                containers[i][].containers,
                containers[i][].lists,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_set_key_at_path_impl(
                segments,
                seg_idx + 1,
                key,
                lists[i][].containers,
                lists[i][].lists,
            ):
                applied = True
    return applied


def refine_add_unique_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read unique_spec: List[String],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(lists)):
            if ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].unique_specs.append(unique_spec.copy())
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if ident_local_name_impl(containers[i][].name) == seg:
            if refine_add_unique_at_path_impl(
                segments,
                seg_idx + 1,
                unique_spec,
                containers[i][].containers,
                containers[i][].lists,
            ):
                applied = True
    for i in range(len(lists)):
        if ident_local_name_impl(lists[i][].name) == seg:
            if refine_add_unique_at_path_impl(
                segments,
                seg_idx + 1,
                unique_spec,
                lists[i][].containers,
                lists[i][].lists,
            ):
                applied = True
    return applied
