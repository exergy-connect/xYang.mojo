## Text YANG parser for Mojo AST (modeled after Python xYang parser flow).
##
## Supported subset:
## - module header: module, namespace, prefix, description, revision (list, body skipped)
## - data nodes: container, list, leaf, choice/case
## - leaf/list details: type, mandatory, key
## - must on leaves with optional error-message/description block

from std.collections import Dict
from std.memory import ArcPointer, UnsafePointer
import xyang.ast as ast
from xyang.yang.parser.tokenizer import tokenize_yang_impl
from xyang.yang.parser.module_stmt import parse_module_impl
import xyang.yang.parser.grouping_uses_stmt as gu_stmt
import xyang.yang.parser.refine_augment_stmt as ra_stmt
import xyang.yang.parser.node_stmt as node_stmt
import xyang.yang.parser.must_stmt as must_stmt
import xyang.yang.parser.type_constraint_stmt as tc_stmt
import xyang.yang.parser.when_stmt as when_stmt
import xyang.yang.parser.clone_utils as clone_utils
import xyang.yang.parser.semantics_utils as sem_utils
from xyang.yang.parser.parser_contract import ParserContract
import xyang.yang.parser.yang_token as yang_token
from xyang.yang.parser.yang_token import YangToken
from xyang.yang.parser.parsed_augment import ParsedAugment

comptime Arc = ArcPointer


struct _YangParser(Movable, ParserContract):
    var tokens: List[YangToken]
    var source: String
    var index: Int
    var groupings: Dict[String, Arc[ast.YangGrouping]]
    var typedefs: Dict[String, Arc[ast.YangType]]
    var typedef_statements: Dict[String, Arc[ast.YangTypedefStmt]]
    var identities: Dict[String, Arc[ast.YangIdentityStmt]]
    var extensions: Dict[String, Arc[ast.YangExtensionStmt]]
    var import_prefixes: Dict[String, Arc[ast.YangModuleImport]]
    var module_statements: List[ast.YangModuleStatement]
    var feature_if_features: Dict[String, List[String]]
    var pending_module_augments: List[Arc[ParsedAugment]]
    ## Built-in `type` keyword → parse function (`tc_stmt.new_builtin_type_parser_table`).
    var _builtin_type_parsers: Dict[
        String, fn (mut _YangParser, String, out ast.YangType) raises
    ]

    def __init__(out self, source: String):
        self.tokens = tokenize_yang_impl(source)
        self.source = source
        self.index = 0
        self.groupings = Dict[String, Arc[ast.YangGrouping]]()
        self.typedefs = Dict[String, Arc[ast.YangType]]()
        self.typedef_statements = Dict[String, Arc[ast.YangTypedefStmt]]()
        self.identities = Dict[String, Arc[ast.YangIdentityStmt]]()
        self.extensions = Dict[String, Arc[ast.YangExtensionStmt]]()
        self.import_prefixes = Dict[String, Arc[ast.YangModuleImport]]()
        self.module_statements = List[ast.YangModuleStatement]()
        self.feature_if_features = Dict[String, List[String]]()
        self.pending_module_augments = List[Arc[ParsedAugment]]()
        self._builtin_type_parsers = tc_stmt.new_builtin_type_parser_table[_YangParser]()

    def _queue_pending_module_augment(mut self, var aug: ParsedAugment):
        self.pending_module_augments.append(Arc[ParsedAugment](aug^))

    def parse_module(mut self) raises -> ast.YangModule:
        return parse_module_impl(self)

    def _prime_groupings_for_current_module_body(mut self) raises:
        var module_body_start = self.index
        var unresolved_stmt_index = -1
        var unresolved_message = ""

        while True:
            var added_in_pass = 0
            var unresolved_in_pass = 0
            self.index = module_body_start

            while self._has_more() and self._peek() != YangToken.RBRACE:
                if self._peek() == YangToken.GROUPING:
                    var grouping_name = self._peek_value_n(1)
                    if len(grouping_name) > 0 and self.groupings.get(
                        grouping_name
                    ):
                        self._skip_statement()
                        continue
                    var stmt_start = self.index
                    var before = len(self.groupings)
                    try:
                        self._parse_grouping_statement()
                        if len(self.groupings) > before:
                            added_in_pass += 1
                    except e:
                        var msg = String(e)
                        if _is_unknown_grouping_uses_error(msg):
                            unresolved_in_pass += 1
                            unresolved_stmt_index = stmt_start
                            unresolved_message = msg
                            # Defer this grouping to a later pass and keep scanning.
                            self.index = stmt_start
                            self._skip_statement()
                        else:
                            raise e^
                else:
                    self._skip_statement()

            if unresolved_in_pass == 0:
                break
            if added_in_pass == 0:
                if unresolved_stmt_index >= 0:
                    self.index = unresolved_stmt_index
                    self._error(_message_after_colon(unresolved_message))
                self._error("Unknown grouping in uses statement")

        # Restore parser position so the normal module parse can begin at the same place.
        self.index = module_body_start

    def _parse_container_statement(mut self) raises -> ast.YangContainer:
        return node_stmt.parse_container_statement_impl(self)

    def _parse_list_statement(mut self) raises -> ast.YangList:
        return node_stmt.parse_list_statement_impl(self)

    def _parse_leaf_statement(mut self) raises -> ast.YangLeaf:
        return node_stmt.parse_leaf_statement_impl(self)

    def _parse_leaf_list_statement(mut self) raises -> ast.YangLeafList:
        return node_stmt.parse_leaf_list_statement_impl(self)

    def _peek_prefixed_extension(ref self) -> Bool:
        ## True when the next statement looks like `prefix:extension-name ...` (RFC 7950 extension).
        return node_stmt.peek_prefixed_extension_impl(self)

    def _skip_prefixed_extension_statement(mut self) raises:
        var prefix = self._peek_value()
        var name = self._peek_value_n(2)
        var keyword = prefix + ":" + name
        self._record_module_statement(
            ast.YangModuleStatement(
                Arc[ast.YangUnknownStatement](
                    ast.YangUnknownStatement(
                        keyword=keyword, argument="", has_argument=False
                    ),
                ),
            ),
        )
        node_stmt.skip_prefixed_extension_statement_impl(self)

    def _parse_anydata_statement(mut self) raises -> ast.YangAnydata:
        return node_stmt.parse_anydata_statement_impl(self)

    def _parse_anyxml_statement(mut self) raises -> ast.YangAnyxml:
        return node_stmt.parse_anyxml_statement_impl(self)

    def _parse_choice_statement(mut self) raises -> ast.YangChoice:
        return node_stmt.parse_choice_statement_impl(self)

    def _parse_case_statement(mut self) raises -> ast.YangChoiceCase:
        return node_stmt.parse_case_statement_impl(self)

    def _parse_grouping_statement(mut self) raises:
        gu_stmt.parse_grouping_statement_impl(self)

    def _store_grouping(mut self, var grouping: ast.YangGrouping) raises:
        var grouping_name = grouping.name
        if self.groupings.get(grouping_name):
            self._error("Duplicate grouping '" + grouping_name + "'")
        self.groupings[grouping_name] = Arc[ast.YangGrouping](grouping^)

    def _get_groupings_snapshot(
        ref self,
    ) -> Dict[String, Arc[ast.YangGrouping]]:
        return self.groupings.copy()

    def _parse_typedef_statement(mut self) raises:
        tc_stmt.parse_typedef_statement_impl(self)

    def _store_typedef(
        mut self, name: String, read type_stmt: ast.YangType, description: String
    ) raises:
        if self.typedefs.get(name):
            self._error("Duplicate typedef '" + name + "'")
        self.typedefs[name] = Arc[ast.YangType](
            clone_utils.clone_yang_type_impl(type_stmt)
        )
        self.typedef_statements[name] = Arc[ast.YangTypedefStmt](
            ast.YangTypedefStmt(
                name=name,
                type_stmt=clone_utils.clone_yang_type_impl(type_stmt),
                description=description,
            ),
        )

    def _resolve_typedef_type(
        ref self, name: String
    ) -> Optional[Arc[ast.YangType]]:
        return self.typedefs.get(name)

    def _parse_yang_type(
        mut self, read type_name: String
    ) raises -> ast.YangType:
        var f = self._builtin_type_parsers.get(type_name)
        var t = String(type_name)
        if f:
            return f.value()(self, t^)
        return ast.YangType(
            name=t^,
            constraints=ast.YangTypeTypedef(
                resolved=UnsafePointer[ast.YangTypedefStmt, MutExternalOrigin](),
            ),
        )

    def _get_typedef_statements_snapshot(
        ref self,
    ) -> Dict[String, Arc[ast.YangTypedefStmt]]:
        return self.typedef_statements.copy()

    def _record_module_statement(mut self, read stmt: ast.YangModuleStatement):
        self.module_statements.append(stmt)

    def _module_statements_snapshot(ref self) -> List[ast.YangModuleStatement]:
        return self.module_statements.copy()

    def _record_feature_if_feature(
        mut self, feature_name: String, if_feature: String
    ):
        var current = self.feature_if_features.get(feature_name)
        if current:
            var values = current.value().copy()
            values.append(if_feature)
            self.feature_if_features[feature_name] = values^
        else:
            var values = List[String]()
            values.append(if_feature)
            self.feature_if_features[feature_name] = values^

    def _feature_if_features_snapshot(ref self) -> Dict[String, List[String]]:
        return self.feature_if_features.copy()

    def _identities_snapshot(
        ref self,
    ) -> Dict[String, Arc[ast.YangIdentityStmt]]:
        return self.identities.copy()

    def _extensions_snapshot(
        ref self,
    ) -> Dict[String, Arc[ast.YangExtensionStmt]]:
        return self.extensions.copy()

    def _import_prefixes_snapshot(
        ref self,
    ) -> Dict[String, Arc[ast.YangModuleImport]]:
        return self.import_prefixes.copy()

    def _parse_uses_statement(
        mut self,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut anydatas: List[Arc[ast.YangAnydata]],
        mut anyxmls: List[Arc[ast.YangAnyxml]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) raises:
        var grouping_name = self._peek_value_n(1)
        self._record_module_statement(
            ast.YangModuleStatement(
                Arc[ast.YangUsesStmt](
                    ast.YangUsesStmt(
                        grouping_name=grouping_name,
                        if_features=List[String](),
                        has_when=False,
                        when=Optional[ast.YangWhen](),
                    ),
                ),
            ),
        )
        gu_stmt.parse_uses_statement_impl(
            self,
            leaves,
            leaf_lists,
            anydatas,
            anyxmls,
            containers,
            lists,
            choices,
        )

    def _append_grouping_nodes_by_name(
        ref self,
        grouping_name: String,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut anydatas: List[Arc[ast.YangAnydata]],
        mut anyxmls: List[Arc[ast.YangAnyxml]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) raises:
        var grouping_opt = self.groupings.get(grouping_name)
        if not grouping_opt:
            self._error(
                "Unknown grouping '" + grouping_name + "' in uses statement"
            )
        ref grouping = grouping_opt.value()[]
        for i in range(len(grouping.children)):
            var child = grouping.children[i]
            if child.isa[Arc[ast.YangLeaf]]():
                leaves.append(
                    clone_utils.clone_leaf_arc_impl(child[Arc[ast.YangLeaf]])
                )
            elif child.isa[Arc[ast.YangLeafList]]():
                leaf_lists.append(
                    clone_utils.clone_leaf_list_arc_impl(
                        child[Arc[ast.YangLeafList]]
                    )
                )
            elif child.isa[Arc[ast.YangAnydata]]():
                anydatas.append(
                    clone_utils.clone_anydata_arc_impl(
                        child[Arc[ast.YangAnydata]]
                    )
                )
            elif child.isa[Arc[ast.YangAnyxml]]():
                anyxmls.append(
                    clone_utils.clone_anyxml_arc_impl(
                        child[Arc[ast.YangAnyxml]]
                    )
                )
            elif child.isa[Arc[ast.YangContainer]]():
                containers.append(
                    clone_utils.clone_container_arc_impl(
                        child[Arc[ast.YangContainer]]
                    )
                )
            elif child.isa[Arc[ast.YangList]]():
                lists.append(
                    clone_utils.clone_list_arc_impl(child[Arc[ast.YangList]])
                )
            elif child.isa[Arc[ast.YangChoice]]():
                choices.append(
                    clone_utils.clone_choice_arc_impl(
                        child[Arc[ast.YangChoice]]
                    )
                )

    def _parse_if_feature_statement(mut self) raises:
        var if_feature = self._peek_value_n(1)
        self._record_feature_if_feature("__module__", if_feature)
        gu_stmt.parse_if_feature_statement_impl(self)

    def _parse_refine_statement(
        mut self,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut anydatas: List[Arc[ast.YangAnydata]],
        mut anyxmls: List[Arc[ast.YangAnyxml]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) raises:
        var refine_stmt = ra_stmt.parse_refine_statement_impl(
            self,
            leaves,
            leaf_lists,
            anydatas,
            anyxmls,
            containers,
            lists,
            choices,
        )
        self._record_module_statement(
            ast.YangModuleStatement(
                Arc[ast.YangRefineStmt](refine_stmt^),
            ),
        )

    def _parse_relative_augment_statement(
        mut self,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut anydatas: List[Arc[ast.YangAnydata]],
        mut anyxmls: List[Arc[ast.YangAnyxml]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) raises:
        var augment_path = self._peek_value_n(1)
        self._record_module_statement(
            ast.YangModuleStatement(
                Arc[ast.YangAugmentStmt](
                    ast.YangAugmentStmt(
                        augment_path=augment_path,
                        if_features=List[String](),
                        has_when=False,
                        when=Optional[ast.YangWhen](),
                    ),
                ),
            ),
        )
        ra_stmt.parse_relative_augment_statement_impl(
            self,
            leaves,
            leaf_lists,
            anydatas,
            anyxmls,
            containers,
            lists,
            choices,
        )

    def _parse_module_augment_statement(
        mut self,
        mut top_containers: List[Arc[ast.YangContainer]],
    ) raises:
        var augment_path = self._peek_value_n(1)
        self._record_module_statement(
            ast.YangModuleStatement(
                Arc[ast.YangAugmentStmt](
                    ast.YangAugmentStmt(
                        augment_path=augment_path,
                        if_features=List[String](),
                        has_when=False,
                        when=Optional[ast.YangWhen](),
                    ),
                ),
            ),
        )
        ra_stmt.parse_module_augment_statement_impl(self, top_containers)

    def _apply_pending_module_augments(
        mut self,
        mut top_containers: List[Arc[ast.YangContainer]],
    ) raises:
        var failed_path = ra_stmt.apply_pending_module_augments_impl(
            self.pending_module_augments,
            top_containers,
        )
        if len(failed_path) > 0:
            self._error("Unknown augment target path '" + failed_path + "'")

    def _parse_augment_statement_body(mut self) raises -> ParsedAugment:
        return ra_stmt.parse_augment_statement_body_impl(self)

    def _apply_augment_to_path(
        ref self,
        path: String,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut anydatas: List[Arc[ast.YangAnydata]],
        mut anyxmls: List[Arc[ast.YangAnyxml]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
        read aug: ParsedAugment,
    ) raises -> Bool:
        return ra_stmt.apply_augment_to_path_impl(
            path,
            leaves,
            leaf_lists,
            anydatas,
            anyxmls,
            containers,
            lists,
            choices,
            aug,
        )

    def _apply_augment_segments(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut anydatas: List[Arc[ast.YangAnydata]],
        mut anyxmls: List[Arc[ast.YangAnyxml]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
        read aug: ParsedAugment,
    ) raises -> Bool:
        return ra_stmt.apply_augment_segments_impl(
            segments,
            seg_idx,
            leaves,
            leaf_lists,
            anydatas,
            anyxmls,
            containers,
            lists,
            choices,
            aug,
        )

    def _refine_set_description_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        description: String,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) -> Bool:
        return ra_stmt.refine_set_description_at_path_impl(
            segments,
            seg_idx,
            description,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
        )

    def _refine_set_mandatory_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        mandatory: Bool,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) -> Bool:
        return ra_stmt.refine_set_mandatory_at_path_impl(
            segments,
            seg_idx,
            mandatory,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
        )

    def _refine_set_default_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        default_value: String,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) -> Bool:
        return ra_stmt.refine_set_default_at_path_impl(
            segments,
            seg_idx,
            default_value,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
        )

    def _refine_add_must_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        read must_stmt: ast.YangMust,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) raises -> Bool:
        return ra_stmt.refine_add_must_at_path_impl(
            segments,
            seg_idx,
            must_stmt,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
        )

    def _refine_set_when_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        read when_stmt: ast.YangWhen,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) raises -> Bool:
        return ra_stmt.refine_set_when_at_path_impl(
            segments,
            seg_idx,
            when_stmt,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
        )

    def _refine_set_type_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        read type_stmt: ast.YangType,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
        mut choices: List[Arc[ast.YangChoice]],
    ) -> Bool:
        return ra_stmt.refine_set_type_at_path_impl(
            segments,
            seg_idx,
            type_stmt,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
        )

    def _refine_set_min_elements_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        value: Int,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
    ) -> Bool:
        return ra_stmt.refine_set_min_elements_at_path_impl(
            segments,
            seg_idx,
            value,
            leaves,
            leaf_lists,
            containers,
            lists,
        )

    def _refine_set_max_elements_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        value: Int,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
    ) -> Bool:
        return ra_stmt.refine_set_max_elements_at_path_impl(
            segments,
            seg_idx,
            value,
            leaves,
            leaf_lists,
            containers,
            lists,
        )

    def _refine_set_ordered_by_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        value: String,
        mut leaves: List[Arc[ast.YangLeaf]],
        mut leaf_lists: List[Arc[ast.YangLeafList]],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
    ) -> Bool:
        return ra_stmt.refine_set_ordered_by_at_path_impl(
            segments,
            seg_idx,
            value,
            leaves,
            leaf_lists,
            containers,
            lists,
        )

    def _refine_set_key_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        key: String,
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
    ) -> Bool:
        return ra_stmt.refine_set_key_at_path_impl(
            segments, seg_idx, key, containers, lists
        )

    def _refine_add_unique_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        read unique_spec: List[String],
        mut containers: List[Arc[ast.YangContainer]],
        mut lists: List[Arc[ast.YangList]],
    ) -> Bool:
        return ra_stmt.refine_add_unique_at_path_impl(
            segments, seg_idx, unique_spec, containers, lists
        )

    def _split_schema_path(ref self, path: String) -> List[String]:
        return clone_utils.split_schema_path_impl(path)

    def _ident_local_name(ref self, ident: String) -> String:
        return clone_utils.ident_local_name_impl(ident)

    def _clone_must(ref self, read src: ast.YangMust) raises -> ast.YangMust:
        return clone_utils.clone_must_impl(src)

    def _clone_when(ref self, read src: ast.YangWhen) raises -> ast.YangWhen:
        return clone_utils.clone_when_impl(src)

    def _clone_yang_type(ref self, read src: ast.YangType) -> ast.YangType:
        return clone_utils.clone_yang_type_impl(src)

    def _clone_leaf_arc(
        ref self, read src: Arc[ast.YangLeaf]
    ) raises -> Arc[ast.YangLeaf]:
        return clone_utils.clone_leaf_arc_impl(src)

    def _clone_leaf_list_arc(
        ref self, read src: Arc[ast.YangLeafList]
    ) raises -> Arc[ast.YangLeafList]:
        return clone_utils.clone_leaf_list_arc_impl(src)

    def _clone_choice_arc(
        ref self, read src: Arc[ast.YangChoice]
    ) raises -> Arc[ast.YangChoice]:
        return clone_utils.clone_choice_arc_impl(src)

    def _clone_anydata_arc(
        ref self, read src: Arc[ast.YangAnydata]
    ) raises -> Arc[ast.YangAnydata]:
        return clone_utils.clone_anydata_arc_impl(src)

    def _clone_anyxml_arc(
        ref self, read src: Arc[ast.YangAnyxml]
    ) raises -> Arc[ast.YangAnyxml]:
        return clone_utils.clone_anyxml_arc_impl(src)

    def _clone_container_arc(
        ref self, read src: Arc[ast.YangContainer]
    ) raises -> Arc[ast.YangContainer]:
        return clone_utils.clone_container_arc_impl(src)

    def _clone_list_arc(
        ref self, read src: Arc[ast.YangList]
    ) raises -> Arc[ast.YangList]:
        return clone_utils.clone_list_arc_impl(src)

    def _parse_type_statement(mut self) raises -> ast.YangType:
        return tc_stmt.parse_type_statement_impl(self)

    def _parse_must_statement(mut self) raises -> ast.YangMust:
        return must_stmt.parse_must_statement_impl(self)

    def _parse_when_statement(mut self) raises -> ast.YangWhen:
        return when_stmt.parse_when_statement_impl(self)

    def _parse_non_negative_int(mut self, label: String) raises -> Int:
        return sem_utils.parse_non_negative_int_impl(self, label)

    def _parse_ordered_by_argument(mut self) raises -> String:
        return sem_utils.parse_ordered_by_argument_impl(self)

    def _unique_components_from_argument(
        mut self, arg: String
    ) raises -> List[String]:
        return sem_utils.unique_components_from_argument_impl(arg)

    def _validate_choice_unique_node_names(
        mut self, read choice: ast.YangChoice
    ) raises:
        sem_utils.validate_choice_unique_node_names_impl(self, choice)

    def _parse_boolean_value(mut self) raises -> Bool:
        return sem_utils.parse_boolean_value_impl(self)

    def _consume_argument_value(mut self) raises -> String:
        if not self._has_more():
            self._error("Expected argument value, found end of input")
            return ""

        var value = self._consume_value()

        # YANG string concatenation: "a" + "b"
        while self._consume_if(YangToken.PLUS):
            value += self._consume_value()

        return value

    def _consume_name(mut self) raises -> String:
        var first_type = self._peek()
        var first = self._consume_value()
        if (
            first_type == YangToken.LBRACE
            or first_type == YangToken.RBRACE
            or first_type == YangToken.SEMICOLON
        ):
            self._error("Expected statement argument, got '" + first + "'")
            return ""

        var name = first
        while self._consume_if(YangToken.COLON):
            name += ":"
            name += self._consume_value()
        return name

    def _skip_statement_tail(mut self) raises:
        if self._consume_if(YangToken.SEMICOLON):
            return
        if self._consume_if(YangToken.LBRACE):
            self._skip_block_body()
            self._skip_if(YangToken.SEMICOLON)
            return
        while self._has_more():
            var v = self._peek()
            if v == YangToken.SEMICOLON:
                self._consume()
                return
            if v == YangToken.LBRACE:
                self._consume()
                self._skip_block_body()
                self._skip_if(YangToken.SEMICOLON)
                return
            if v == YangToken.RBRACE:
                return
            self._consume()

    def _skip_statement(mut self) raises:
        self._consume()
        self._skip_statement_tail()

    def _skip_block_body(mut self) raises:
        # Entry point assumes the opening '{' was already consumed.
        var depth = 1
        while self._has_more() and depth > 0:
            var t = self._peek()
            self._consume()
            if t == YangToken.LBRACE:
                depth += 1
            elif t == YangToken.RBRACE:
                depth -= 1

    def _expect(mut self, value: YangToken.Type) raises:
        if not self._has_more():
            if len(self.tokens) > 0:
                ref last = self.tokens[len(self.tokens) - 1]
                raise Error(
                    "YANG parse error at end of input: Expected "
                    + _token_type_name(value)
                    + ", found end of input after last token "
                    + _token_type_name(last.type)
                    + " ('"
                    + _token_text(self.source, last)
                    + "') at line "
                    + String(last.line)
                    + ", col "
                    + String(_col_for_token(self.source, last)),
                )
            self._error(
                "Expected " + _token_type_name(value) + ", found end of input"
            )
            return
        var got = self._peek()
        if got != value:
            self._error(
                "Expected "
                + _token_type_name(value)
                + ", got "
                + _token_type_name(got),
            )
            return
        self.index += 1

    def _consume_if(mut self, value: YangToken.Type) -> Bool:
        if self._has_more() and self._peek() == value:
            self.index += 1
            return True
        return False

    def _skip_if(mut self, value: YangToken.Type):
        if self._has_more() and self._peek() == value:
            self.index += 1

    def _consume(mut self) raises:
        if not self._has_more():
            self._error("Unexpected end of input")
            return
        _ = self._consume_value()

    def _consume_value(mut self) raises -> String:
        if not self._has_more():
            self._error("Unexpected end of input")
            return ""
        ref tok = self.tokens[self.index]
        var out = _token_text(
            self.source, tok, strip_quotes=tok.type == YangToken.STRING
        )
        self.index += 1
        return out

    def _peek(ref self) -> YangToken.Type:
        return self.tokens[self.index].type

    def _peek_n(ref self, offset: Int) -> YangToken.Type:
        var idx = self.index + offset
        if idx < 0 or idx >= len(self.tokens):
            return YangToken.UNKNOWN
        return self.tokens[idx].type

    def _peek_value(ref self) -> String:
        return _token_text(self.source, self.tokens[self.index])

    def _peek_value_n(ref self, offset: Int) -> String:
        var idx = self.index + offset
        if idx < 0 or idx >= len(self.tokens):
            return ""
        return _token_text(self.source, self.tokens[idx])

    def _has_more(ref self) -> Bool:
        return self.index < len(self.tokens)

    def _error(ref self, message: String) raises:
        if self._has_more():
            ref tok = self.tokens[self.index]
            raise Error(
                "YANG parse error at line "
                + String(tok.line)
                + ", col "
                + String(_col_for_token(self.source, tok))
                + ": "
                + message,
            )
        raise Error("YANG parse error at end of input: " + message)


def _token_text(
    source: String, read tok: YangToken, strip_quotes: Bool = False
) -> String:
    return tok.text(source, strip_quotes=strip_quotes)


def _token_type_name(t: YangToken.Type) -> String:
    if t == YangToken.LBRACE:
        return "'{'"
    if t == YangToken.RBRACE:
        return "'}'"
    if t == YangToken.SEMICOLON:
        return "';'"
    if t == YangToken.COLON:
        return "':'"
    if t == YangToken.PLUS:
        return "'+'"
    if t == YangToken.MODULE:
        return "'module'"
    if t == YangToken.GROUPING:
        return "'grouping'"
    if t == YangToken.TYPEDEF:
        return "'typedef'"
    if t == YangToken.USES:
        return "'uses'"
    if t == YangToken.AUGMENT:
        return "'augment'"
    if t == YangToken.CONTAINER:
        return "'container'"
    if t == YangToken.LIST:
        return "'list'"
    if t == YangToken.LEAF:
        return "'leaf'"
    if t == YangToken.LEAF_LIST:
        return "'leaf-list'"
    if t == YangToken.CHOICE:
        return "'choice'"
    if t == YangToken.CASE:
        return "'case'"
    if t == YangToken.TYPE:
        return "'type'"
    if t == YangToken.STRING:
        return "string"
    if t == YangToken.IDENTIFIER:
        return "identifier"
    if t == YangToken.INTEGER:
        return "integer"
    return "token#" + String(t)


def _col_for_token(source: String, tok: YangToken) -> Int:
    var i = tok.start
    while i > 0:
        if source[byte = i - 1 : i] == "\n":
            break
        i -= 1
    return tok.start - i


def _is_unknown_grouping_uses_error(message: String) -> Bool:
    return _contains_substr(message, "Unknown grouping '") and _contains_substr(
        message,
        " in uses statement",
    )


def _contains_substr(haystack: String, needle: String) -> Bool:
    return len(haystack.split(needle)) > 1


def _message_after_colon(message: String) -> String:
    var sep = ": "
    var parts = message.split(sep)
    if len(parts) == 0:
        return message
    return String(parts[len(parts) - 1])
