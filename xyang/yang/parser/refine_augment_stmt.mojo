from std.memory import ArcPointer
import xyang.ast as ast
from xyang.xpath.path_parser import local_names_from_slashed_path_parts, parse_path
from xyang.yang.parser.yang_token import YangToken
from xyang.yang.parser.parser_contract import ParserContract
import xyang.yang.parser.clone_utils as clone_utils
import xyang.yang.parser.grouping_uses_stmt as gu_stmt

comptime Arc = ArcPointer


def append_cloned_augment_statement_children(
    read aug: ast.YangAugmentStmt,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut anydatas: List[Arc[ast.YangAnydata]],
    mut anyxmls: List[Arc[ast.YangAnyxml]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) raises:
    for i in range(len(aug.statements)):
        var st = aug.statements[i]
        if st.isa[Arc[ast.YangLeaf]]():
            leaves.append(clone_utils.clone_leaf_arc_impl(st[Arc[ast.YangLeaf]]))
        elif st.isa[Arc[ast.YangLeafList]]():
            leaf_lists.append(
                clone_utils.clone_leaf_list_arc_impl(st[Arc[ast.YangLeafList]])
            )
        elif st.isa[Arc[ast.YangAnydata]]():
            anydatas.append(clone_utils.clone_anydata_arc_impl(st[Arc[ast.YangAnydata]]))
        elif st.isa[Arc[ast.YangAnyxml]]():
            anyxmls.append(clone_utils.clone_anyxml_arc_impl(st[Arc[ast.YangAnyxml]]))
        elif st.isa[Arc[ast.YangContainer]]():
            containers.append(
                clone_utils.clone_container_arc_impl(st[Arc[ast.YangContainer]])
            )
        elif st.isa[Arc[ast.YangList]]():
            lists.append(clone_utils.clone_list_arc_impl(st[Arc[ast.YangList]]))
        elif st.isa[Arc[ast.YangChoice]]():
            choices.append(clone_utils.clone_choice_arc_impl(st[Arc[ast.YangChoice]]))


def _join_slashed_path_parts(read parts: List[String]) -> String:
    var out = String("")
    for i in range(len(parts)):
        if i > 0:
            out += "/"
        out += parts[i]
    return out^


def _local_segments_from_schema_path_string(path: String) raises -> List[String]:
    """String-only path (e.g. augment); single ``parse_path`` of the full argument."""
    var parsed = parse_path(path)
    var out = List[String]()
    for i in range(len(parsed.segments)):
        out.append(parsed.segments[i].local_name)
    return out^


## Refined from ``xyang/parser/statements/refine.py::RefineStatementParser``:
## slash-separated `node-identifier` segments (``parts.append`` / ``".".join"`` in Python
## is the same as ``/``.join for schema paths).


def _consume_refine_slashed_path_parts[ParserT: ParserContract](mut parser: ParserT) raises -> List[String]:
    """Token `/` steps only; one ``local_names_from_slashed_path_parts`` + one join, no re-split of a full string."""
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


## Handlers in ``refine.py::RefineStatementParser`` for MANDATORY and DEFAULT
## (``_parse_refine_mandatory`` / ``_parse_refine_default``).


def _parse_refine_mandatory_substmt_at_path[ParserT: ParserContract](
    mut parser: ParserT,
    read segments: List[String],
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
    mut refine: ast.YangRefineStmt,
) raises:
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
        parser._error("Unknown refine target path '" + refine.target_path + "'")
    refine.mandatory = Optional[Bool](mandatory)


def _parse_refine_default_substmt_at_path[ParserT: ParserContract](
    mut parser: ParserT,
    read segments: List[String],
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
    mut refine: ast.YangRefineStmt,
) raises:
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
        parser._error("Unknown refine target path '" + refine.target_path + "'")
    refine.default_values.append(default_value^)


## One substatement in ``refine { ... }``: dispatch keys align with
## ``RefineStatementParser._refine_substatement_dispatch`` in ``refine.py``.


def _parse_refine_substatement_at_path_impl[ParserT: ParserContract](
    mut parser: ParserT,
    read segments: List[String],
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut anydatas: List[Arc[ast.YangAnydata]],
    mut anyxmls: List[Arc[ast.YangAnyxml]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
    mut refine: ast.YangRefineStmt,
) raises:
    _ = anydatas
    _ = anyxmls
    var tt = parser._peek()
    if tt == YangToken.MUST:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
        refine.must.must_statements.append(Arc[ast.YangMust](clone_utils.clone_must_impl(must_stmt)))
    elif tt == YangToken.DESCRIPTION:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
        refine.description = Optional[String](desc^)
    elif tt == YangToken.MIN_ELEMENTS:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
        refine.min_elements = Optional[Int](min_el)
    elif tt == YangToken.MAX_ELEMENTS:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
        refine.max_elements = Optional[Int](max_el)
    elif tt == YangToken.ORDERED_BY:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
    elif tt == YangToken.MANDATORY:
        _parse_refine_mandatory_substmt_at_path(
            parser,
            segments,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
            refine,
        )
    elif tt == YangToken.DEFAULT:
        _parse_refine_default_substmt_at_path(
            parser,
            segments,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
            refine,
        )
    elif tt == YangToken.IF_FEATURE:
        var if_feature_expr = parser._peek_value_n(1)
        parser._record_feature_if_feature("__module__", if_feature_expr)
        gu_stmt.parse_if_feature_statement_impl(parser)
        refine.if_features.append(if_feature_expr^)
    elif tt == YangToken.TYPE:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
    elif parser._peek_prefixed_extension():
        parser._skip_prefixed_extension_statement()
    elif tt == YangToken.WHEN:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
        refine.set_when(Optional[ast.YangWhen](when_stmt^))
    elif tt == YangToken.KEY:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
    elif tt == YangToken.UNIQUE:
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
            parser._error("Unknown refine target path '" + refine.target_path + "'")
    else:
        parser._skip_statement()


def parse_refine_statement_impl[ParserT: ParserContract](
    mut parser: ParserT,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut anydatas: List[Arc[ast.YangAnydata]],
    mut anyxmls: List[Arc[ast.YangAnyxml]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) raises -> ast.YangRefineStmt:
    _ = anydatas
    _ = anyxmls
    parser._expect(YangToken.REFINE)
    var path_parts = _consume_refine_slashed_path_parts(parser)
    var refine_path = _join_slashed_path_parts(path_parts)
    var segments = local_names_from_slashed_path_parts(path_parts^)
    if len(segments) == 0:
        parser._error("refine requires a descendant schema-node identifier")
        parser._skip_statement_tail()
        return ast.YangRefineStmt(
            target_path = "",
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

    var refine = ast.YangRefineStmt(
        target_path = refine_path^,
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
            _parse_refine_substatement_at_path_impl(
                parser,
                segments,
                leaves,
                leaf_lists,
                anydatas,
                anyxmls,
                containers,
                lists,
                choices,
                refine,
            )
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)
    return refine^


def parse_relative_augment_statement_impl[ParserT: ParserContract](
    mut parser: ParserT,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut anydatas: List[Arc[ast.YangAnydata]],
    mut anyxmls: List[Arc[ast.YangAnyxml]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) raises:
    var stmt = parse_augment_statement_body_impl(parser)
    var ap = stmt.augment_path
    var is_abs = len(ap) > 0 and String(ap[byte=0:1]) == "/"
    if is_abs:
        var arc = Arc[ast.YangAugmentStmt](stmt^)
        parser._queue_pending_module_augment(arc.copy())
        parser._record_module_statement(
            ast.YangModuleStatement(arc^),
        )
        return
    if not apply_augment_to_path_impl(
        stmt.augment_path,
        leaves,
        leaf_lists,
        anydatas,
        anyxmls,
        containers,
        lists,
        choices,
        stmt,
    ):
        parser._error("Unknown augment target path '" + stmt.augment_path + "'")
    parser._record_module_statement(
        ast.YangModuleStatement(Arc[ast.YangAugmentStmt](stmt^)),
    )


def parse_module_augment_statement_impl[ParserT: ParserContract](
    mut parser: ParserT,
    mut top_containers: List[Arc[ast.YangContainer]],
) raises:
    var stmt = parse_augment_statement_body_impl(parser)
    var ap = stmt.augment_path
    var is_abs = len(ap) > 0 and String(ap[byte=0:1]) == "/"
    if is_abs:
        var arc = Arc[ast.YangAugmentStmt](stmt^)
        parser._queue_pending_module_augment(arc.copy())
        parser._record_module_statement(
            ast.YangModuleStatement(arc^),
        )
        return
    var root_leaves = List[Arc[ast.YangLeaf]]()
    var root_leaf_lists = List[Arc[ast.YangLeafList]]()
    var root_anydatas = List[Arc[ast.YangAnydata]]()
    var root_anyxmls = List[Arc[ast.YangAnyxml]]()
    var root_lists = List[Arc[ast.YangList]]()
    var root_choices = List[Arc[ast.YangChoice]]()
    if not apply_augment_to_path_impl(
        stmt.augment_path,
        root_leaves,
        root_leaf_lists,
        root_anydatas,
        root_anyxmls,
        top_containers,
        root_lists,
        root_choices,
        stmt,
    ):
        parser._error("Unknown augment target path '" + stmt.augment_path + "'")
    parser._record_module_statement(
        ast.YangModuleStatement(Arc[ast.YangAugmentStmt](stmt^)),
    )


def apply_pending_module_augments_impl(
    read pending_module_augments: List[Arc[ast.YangAugmentStmt]],
    mut top_containers: List[Arc[ast.YangContainer]],
) raises -> String:
    var root_leaves = List[Arc[ast.YangLeaf]]()
    var root_leaf_lists = List[Arc[ast.YangLeafList]]()
    var root_anydatas = List[Arc[ast.YangAnydata]]()
    var root_anyxmls = List[Arc[ast.YangAnyxml]]()
    var root_lists = List[Arc[ast.YangList]]()
    var root_choices = List[Arc[ast.YangChoice]]()
    for i in range(len(pending_module_augments)):
        var aug_arc = pending_module_augments[i].copy()
        ref aug = aug_arc[]
        if not apply_augment_to_path_impl(
            aug.augment_path,
            root_leaves,
            root_leaf_lists,
            root_anydatas,
            root_anyxmls,
            top_containers,
            root_lists,
            root_choices,
            aug,
        ):
            return aug.augment_path
    return ""


def parse_augment_statement_body_impl[ParserT: ParserContract](
    mut parser: ParserT,
) raises -> ast.YangAugmentStmt:
    parser._expect(YangToken.AUGMENT)
    var target_path = parser._consume_argument_value()

    var leaves = List[Arc[ast.YangLeaf]]()
    var leaf_lists = List[Arc[ast.YangLeafList]]()
    var anydatas = List[Arc[ast.YangAnydata]]()
    var anyxmls = List[Arc[ast.YangAnyxml]]()
    var containers = List[Arc[ast.YangContainer]]()
    var lists = List[Arc[ast.YangList]]()
    var choices = List[Arc[ast.YangChoice]]()

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.LEAF:
                var leaf = parser._parse_leaf_statement()
                leaves.append(Arc[ast.YangLeaf](leaf^))
            elif stmt == YangToken.LEAF_LIST:
                var leaf_list = parser._parse_leaf_list_statement()
                leaf_lists.append(Arc[ast.YangLeafList](leaf_list^))
            elif stmt == YangToken.ANYDATA:
                var ad = parser._parse_anydata_statement()
                anydatas.append(Arc[ast.YangAnydata](ad^))
            elif stmt == YangToken.ANYXML:
                var ax = parser._parse_anyxml_statement()
                anyxmls.append(Arc[ast.YangAnyxml](ax^))
            elif stmt == YangToken.CONTAINER:
                var child_container = parser._parse_container_statement()
                containers.append(Arc[ast.YangContainer](child_container^))
            elif stmt == YangToken.LIST:
                var child_list = parser._parse_list_statement()
                lists.append(Arc[ast.YangList](child_list^))
            elif stmt == YangToken.CHOICE:
                var choice = parser._parse_choice_statement()
                choices.append(Arc[ast.YangChoice](choice^))
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

    var statements = List[ast.YangAugmentStmt.ChildStatement]()
    for i in range(len(leaves)):
        statements.append(ast.YangAugmentStmt.ChildStatement(leaves[i].copy()))
    for i in range(len(leaf_lists)):
        statements.append(ast.YangAugmentStmt.ChildStatement(leaf_lists[i].copy()))
    for i in range(len(anydatas)):
        statements.append(ast.YangAugmentStmt.ChildStatement(anydatas[i].copy()))
    for i in range(len(anyxmls)):
        statements.append(ast.YangAugmentStmt.ChildStatement(anyxmls[i].copy()))
    for i in range(len(containers)):
        statements.append(ast.YangAugmentStmt.ChildStatement(containers[i].copy()))
    for i in range(len(lists)):
        statements.append(ast.YangAugmentStmt.ChildStatement(lists[i].copy()))
    for i in range(len(choices)):
        statements.append(ast.YangAugmentStmt.ChildStatement(choices[i].copy()))

    return ast.YangAugmentStmt(
        augment_path = target_path^,
        if_features = List[String](),
        when = Optional[ast.YangWhen](),
        statements = statements^,
    )


def apply_augment_to_path_impl(
    path: String,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut anydatas: List[Arc[ast.YangAnydata]],
    mut anyxmls: List[Arc[ast.YangAnyxml]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
    read aug: ast.YangAugmentStmt,
) raises -> Bool:
    var segments = _local_segments_from_schema_path_string(path)
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
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut anydatas: List[Arc[ast.YangAnydata]],
    mut anyxmls: List[Arc[ast.YangAnyxml]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
    read aug: ast.YangAugmentStmt,
) raises -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(containers)):
            if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
                append_cloned_augment_statement_children(
                    aug,
                    containers[i][].leaves,
                    containers[i][].leaf_lists,
                    containers[i][].anydatas,
                    containers[i][].anyxmls,
                    containers[i][].containers,
                    containers[i][].lists,
                    containers[i][].choices,
                )
                applied = True
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                var b_aug = ast.decompose_yang_list_children(lists[i][].children)
                append_cloned_augment_statement_children(
                    aug,
                    b_aug.leaves,
                    b_aug.leaf_lists,
                    b_aug.anydatas,
                    b_aug.anyxmls,
                    b_aug.containers,
                    b_aug.lists,
                    b_aug.choices,
                )
                lists[i][].children = ast.pack_yang_list_child_buckets(b_aug)
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_seg = ast.decompose_yang_list_children(lists[i][].children)
            if apply_augment_segments_impl(
                segments,
                seg_idx + 1,
                b_seg.leaves,
                b_seg.leaf_lists,
                b_seg.anydatas,
                b_seg.anyxmls,
                b_seg.containers,
                b_seg.lists,
                b_seg.choices,
                aug,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_seg)
    return applied


def refine_set_description_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    description: String,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if clone_utils.ident_local_name_impl(leaves[i][].name) == seg:
                # Leaf description is not modeled in the current AST; treat as recognized no-op.
                applied = True
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                # Leaf-list description is not modeled in the current AST; treat as recognized no-op.
                applied = True
        for i in range(len(containers)):
            if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
                containers[i][].description = description
                applied = True
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].description = description
                applied = True
        for i in range(len(choices)):
            if clone_utils.ident_local_name_impl(choices[i][].name) == seg:
                # Choice/case descriptions are not modeled in the current AST; treat as recognized no-op.
                applied = True
            for j in range(len(choices[i][].cases)):
                if clone_utils.ident_local_name_impl(choices[i][].cases[j][].name) == seg:
                    applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_d = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_description_at_path_impl(
                segments,
                seg_idx + 1,
                description,
                b_d.leaves,
                b_d.leaf_lists,
                b_d.containers,
                b_d.lists,
                b_d.choices,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_d)
    return applied


def refine_set_mandatory_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    mandatory: Bool,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if clone_utils.ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].mandatory = mandatory
                applied = True
        for i in range(len(choices)):
            if clone_utils.ident_local_name_impl(choices[i][].name) == seg:
                choices[i][].mandatory = mandatory
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_m = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_mandatory_at_path_impl(
                segments,
                seg_idx + 1,
                mandatory,
                b_m.leaves,
                b_m.leaf_lists,
                b_m.containers,
                b_m.lists,
                b_m.choices,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_m)
    return applied


def refine_set_default_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    default_value: String,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if clone_utils.ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].default_value = default_value
                leaves[i][].has_default = True
                applied = True
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].default_values.append(default_value)
                applied = True
        for i in range(len(choices)):
            if clone_utils.ident_local_name_impl(choices[i][].name) == seg:
                choices[i][].default_case = default_value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_def = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_default_at_path_impl(
                segments,
                seg_idx + 1,
                default_value,
                b_def.leaves,
                b_def.leaf_lists,
                b_def.containers,
                b_def.lists,
                b_def.choices,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_def)
    return applied


def refine_add_must_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read must_stmt: ast.YangMust,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) raises -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if clone_utils.ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].must.must_statements.append(Arc[ast.YangMust](clone_utils.clone_must_impl(must_stmt)))
                applied = True
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].must.must_statements.append(Arc[ast.YangMust](clone_utils.clone_must_impl(must_stmt)))
                applied = True
        for i in range(len(containers)):
            if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
                containers[i][].must.must_statements.append(Arc[ast.YangMust](clone_utils.clone_must_impl(must_stmt)))
                applied = True
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].must.must_statements.append(Arc[ast.YangMust](clone_utils.clone_must_impl(must_stmt)))
                applied = True
        for i in range(len(choices)):
            if clone_utils.ident_local_name_impl(choices[i][].name) == seg:
                # Container/list/choice/case `must` is not modeled in current AST; treat as recognized no-op.
                applied = True
            for j in range(len(choices[i][].cases)):
                if clone_utils.ident_local_name_impl(choices[i][].cases[j][].name) == seg:
                    # Container/list/choice/case `must` is not modeled in current AST; treat as recognized no-op.
                    applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_mu = ast.decompose_yang_list_children(lists[i][].children)
            if refine_add_must_at_path_impl(
                segments,
                seg_idx + 1,
                must_stmt,
                b_mu.leaves,
                b_mu.leaf_lists,
                b_mu.containers,
                b_mu.lists,
                b_mu.choices,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_mu)
    return applied


def refine_set_when_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read when_stmt: ast.YangWhen,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) raises -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if clone_utils.ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].when = Optional(clone_utils.clone_when_impl(when_stmt))
                applied = True
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].when = Optional(clone_utils.clone_when_impl(when_stmt))
                applied = True
        for i in range(len(choices)):
            if clone_utils.ident_local_name_impl(choices[i][].name) == seg:
                choices[i][].when = Optional(clone_utils.clone_when_impl(when_stmt))
                applied = True
            for j in range(len(choices[i][].cases)):
                if clone_utils.ident_local_name_impl(choices[i][].cases[j][].name) == seg:
                    choices[i][].cases[j][].when = Optional(clone_utils.clone_when_impl(when_stmt))
                    applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_w = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_when_at_path_impl(
                segments,
                seg_idx + 1,
                when_stmt,
                b_w.leaves,
                b_w.leaf_lists,
                b_w.containers,
                b_w.lists,
                b_w.choices,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_w)
    return applied


def refine_set_type_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read type_stmt: ast.YangType,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
    mut choices: List[Arc[ast.YangChoice]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaves)):
            if clone_utils.ident_local_name_impl(leaves[i][].name) == seg:
                leaves[i][].type = clone_utils.clone_yang_type_impl(type_stmt)
                applied = True
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].type = clone_utils.clone_yang_type_impl(type_stmt)
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_t = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_type_at_path_impl(
                segments,
                seg_idx + 1,
                type_stmt,
                b_t.leaves,
                b_t.leaf_lists,
                b_t.containers,
                b_t.lists,
                b_t.choices,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_t)
    return applied


def refine_set_min_elements_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    value: Int,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].min_elements = value
                applied = True
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].min_elements = value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_min = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_min_elements_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                b_min.leaves,
                b_min.leaf_lists,
                b_min.containers,
                b_min.lists,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_min)
    return applied


def refine_set_max_elements_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    value: Int,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].max_elements = value
                applied = True
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].max_elements = value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_max = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_max_elements_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                b_max.leaves,
                b_max.leaf_lists,
                b_max.containers,
                b_max.lists,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_max)
    return applied


def refine_set_ordered_by_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    value: String,
    mut leaves: List[Arc[ast.YangLeaf]],
    mut leaf_lists: List[Arc[ast.YangLeafList]],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(leaf_lists)):
            if clone_utils.ident_local_name_impl(leaf_lists[i][].name) == seg:
                leaf_lists[i][].ordered_by = value
                applied = True
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].ordered_by = value
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
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
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_ob = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_ordered_by_at_path_impl(
                segments,
                seg_idx + 1,
                value,
                b_ob.leaves,
                b_ob.leaf_lists,
                b_ob.containers,
                b_ob.lists,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_ob)
    return applied


def refine_set_key_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    key: String,
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].key = key
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
            if refine_set_key_at_path_impl(
                segments,
                seg_idx + 1,
                key,
                containers[i][].containers,
                containers[i][].lists,
            ):
                applied = True
    for i in range(len(lists)):
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_key = ast.decompose_yang_list_children(lists[i][].children)
            if refine_set_key_at_path_impl(
                segments,
                seg_idx + 1,
                key,
                b_key.containers,
                b_key.lists,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_key)
    return applied


def refine_add_unique_at_path_impl(
    read segments: List[String],
    seg_idx: Int,
    read unique_spec: List[String],
    mut containers: List[Arc[ast.YangContainer]],
    mut lists: List[Arc[ast.YangList]],
) -> Bool:
    var seg = segments[seg_idx]
    if seg_idx == len(segments) - 1:
        var applied = False
        for i in range(len(lists)):
            if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
                lists[i][].unique_specs.append(unique_spec.copy())
                applied = True
        return applied

    var applied = False
    for i in range(len(containers)):
        if clone_utils.ident_local_name_impl(containers[i][].name) == seg:
            if refine_add_unique_at_path_impl(
                segments,
                seg_idx + 1,
                unique_spec,
                containers[i][].containers,
                containers[i][].lists,
            ):
                applied = True
    for i in range(len(lists)):
        if clone_utils.ident_local_name_impl(lists[i][].name) == seg:
            var b_uq = ast.decompose_yang_list_children(lists[i][].children)
            if refine_add_unique_at_path_impl(
                segments,
                seg_idx + 1,
                unique_spec,
                b_uq.containers,
                b_uq.lists,
            ):
                applied = True
            lists[i][].children = ast.pack_yang_list_child_buckets(b_uq)
    return applied
