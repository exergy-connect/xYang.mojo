## Text YANG parser for Mojo AST (modeled after Python xYang parser flow).
##
## Supported subset:
## - module header: module, namespace, prefix, description, revision (list, body skipped)
## - data nodes: container, list, leaf, choice/case
## - leaf/list details: type, mandatory, key
## - must on leaves with optional error-message/description block

from std.collections import Dict
from std.memory import ArcPointer
from xyang.ast import (
    YangModule,
    YangContainer,
    YangList,
    YangChoice,
    YangChoiceCase,
    YangLeaf,
    YangLeafList,
    YangAnydata,
    YangAnyxml,
    YangType,
    YangMust,
    YangWhen,
    YangGrouping,
)
from xyang.yang.parser.tokenizer import tokenize_yang_impl
from xyang.yang.parser.module_stmt import parse_module_impl
from xyang.yang.parser.grouping_uses_stmt import (
    parse_grouping_statement_impl,
    parse_uses_statement_impl,
    parse_if_feature_statement_impl,
)
from xyang.yang.parser.refine_augment_stmt import (
    parse_refine_statement_impl,
    parse_relative_augment_statement_impl,
    parse_module_augment_statement_impl,
    apply_pending_module_augments_impl,
    parse_augment_statement_body_impl,
    apply_augment_to_path_impl,
    apply_augment_segments_impl,
    refine_set_description_at_path_impl,
    refine_set_mandatory_at_path_impl,
    refine_set_default_at_path_impl,
    refine_add_must_at_path_impl,
    refine_set_when_at_path_impl,
    refine_set_type_at_path_impl,
    refine_set_min_elements_at_path_impl,
    refine_set_max_elements_at_path_impl,
    refine_set_ordered_by_at_path_impl,
    refine_set_key_at_path_impl,
    refine_add_unique_at_path_impl,
)
from xyang.yang.parser.node_stmt import (
    parse_container_statement_impl,
    parse_list_statement_impl,
    parse_leaf_statement_impl,
    parse_leaf_list_statement_impl,
    peek_prefixed_extension_impl,
    skip_prefixed_extension_statement_impl,
    parse_anydata_statement_impl,
    parse_anyxml_statement_impl,
    parse_choice_statement_impl,
    parse_case_statement_impl,
)
from xyang.yang.parser.type_constraint_stmt import (
    parse_type_statement_impl,
    parse_must_statement_impl,
    parse_when_statement_impl,
)
from xyang.yang.parser.clone_utils import (
    split_schema_path_impl,
    ident_local_name_impl,
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
from xyang.yang.parser.semantics_utils import (
    parse_non_negative_int_impl,
    parse_ordered_by_argument_impl,
    unique_components_from_argument_impl,
    validate_choice_unique_node_names_impl,
    parse_boolean_value_impl,
)
from xyang.yang.parser.parser_contract import ParserContract
from xyang.yang.parser.types import YangToken
from xyang.yang.parser.parsed_augment import ParsedAugment

comptime Arc = ArcPointer


struct _YangParser(Movable, ParserContract):
    var tokens: List[YangToken]
    var source: String
    var index: Int
    var groupings: Dict[String, Arc[YangGrouping]]
    var pending_module_augments: List[Arc[ParsedAugment]]

    def __init__(out self, source: String):
        self.tokens = tokenize_yang_impl(source)
        self.source = source
        self.index = 0
        self.groupings = Dict[String, Arc[YangGrouping]]()
        self.pending_module_augments = List[Arc[ParsedAugment]]()

    def _queue_pending_module_augment(mut self, var aug: ParsedAugment):
        self.pending_module_augments.append(Arc[ParsedAugment](aug^))

    def parse_module(mut self) raises -> YangModule:
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
                    if len(grouping_name) > 0 and self.groupings.get(grouping_name):
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

    def _parse_container_statement(mut self) raises -> YangContainer:
        return parse_container_statement_impl(self)

    def _parse_list_statement(mut self) raises -> YangList:
        return parse_list_statement_impl(self)

    def _parse_leaf_statement(mut self) raises -> YangLeaf:
        return parse_leaf_statement_impl(self)

    def _parse_leaf_list_statement(mut self) raises -> YangLeafList:
        return parse_leaf_list_statement_impl(self)

    def _peek_prefixed_extension(ref self) -> Bool:
        ## True when the next statement looks like `prefix:extension-name ...` (RFC 7950 extension).
        return peek_prefixed_extension_impl(self)

    def _skip_prefixed_extension_statement(mut self) raises:
        skip_prefixed_extension_statement_impl(self)

    def _parse_anydata_statement(mut self) raises -> YangAnydata:
        return parse_anydata_statement_impl(self)

    def _parse_anyxml_statement(mut self) raises -> YangAnyxml:
        return parse_anyxml_statement_impl(self)

    def _parse_choice_statement(mut self) raises -> YangChoice:
        return parse_choice_statement_impl(self)

    def _parse_case_statement(mut self) raises -> YangChoiceCase:
        return parse_case_statement_impl(self)

    def _parse_grouping_statement(mut self) raises:
        parse_grouping_statement_impl(self)

    def _store_grouping(mut self, var grouping: YangGrouping) raises:
        var grouping_name = grouping.name
        if self.groupings.get(grouping_name):
            self._error("Duplicate grouping '" + grouping_name + "'")
        self.groupings[grouping_name] = Arc[YangGrouping](grouping^)

    def _parse_uses_statement(
        mut self,
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut anydatas: List[Arc[YangAnydata]],
        mut anyxmls: List[Arc[YangAnyxml]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) raises:
        parse_uses_statement_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut anydatas: List[Arc[YangAnydata]],
        mut anyxmls: List[Arc[YangAnyxml]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) raises:
        var grouping_opt = self.groupings.get(grouping_name)
        if not grouping_opt:
            self._error("Unknown grouping '" + grouping_name + "' in uses statement")
        ref grouping = grouping_opt.value()[]
        for i in range(len(grouping.children)):
            var child = grouping.children[i]
            if child.isa[Arc[YangLeaf]]():
                leaves.append(clone_leaf_arc_impl(child[Arc[YangLeaf]]))
            elif child.isa[Arc[YangLeafList]]():
                leaf_lists.append(clone_leaf_list_arc_impl(child[Arc[YangLeafList]]))
            elif child.isa[Arc[YangAnydata]]():
                anydatas.append(clone_anydata_arc_impl(child[Arc[YangAnydata]]))
            elif child.isa[Arc[YangAnyxml]]():
                anyxmls.append(clone_anyxml_arc_impl(child[Arc[YangAnyxml]]))
            elif child.isa[Arc[YangContainer]]():
                containers.append(clone_container_arc_impl(child[Arc[YangContainer]]))
            elif child.isa[Arc[YangList]]():
                lists.append(clone_list_arc_impl(child[Arc[YangList]]))
            elif child.isa[Arc[YangChoice]]():
                choices.append(clone_choice_arc_impl(child[Arc[YangChoice]]))

    def _parse_if_feature_statement(mut self) raises:
        parse_if_feature_statement_impl(self)

    def _parse_refine_statement(
        mut self,
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut anydatas: List[Arc[YangAnydata]],
        mut anyxmls: List[Arc[YangAnyxml]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) raises:
        parse_refine_statement_impl(
            self,
            leaves,
            leaf_lists,
            anydatas,
            anyxmls,
            containers,
            lists,
            choices,
        )

    def _parse_relative_augment_statement(
        mut self,
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut anydatas: List[Arc[YangAnydata]],
        mut anyxmls: List[Arc[YangAnyxml]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) raises:
        parse_relative_augment_statement_impl(
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
        mut top_containers: List[Arc[YangContainer]],
    ) raises:
        parse_module_augment_statement_impl(self, top_containers)

    def _apply_pending_module_augments(
        mut self,
        mut top_containers: List[Arc[YangContainer]],
    ) raises:
        var failed_path = apply_pending_module_augments_impl(
            self.pending_module_augments,
            top_containers,
        )
        if len(failed_path) > 0:
            self._error("Unknown augment target path '" + failed_path + "'")

    def _parse_augment_statement_body(mut self) raises -> ParsedAugment:
        return parse_augment_statement_body_impl(self)

    def _apply_augment_to_path(
        ref self,
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
        return apply_augment_to_path_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut anydatas: List[Arc[YangAnydata]],
        mut anyxmls: List[Arc[YangAnyxml]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
        read aug: ParsedAugment,
    ) -> Bool:
        return apply_augment_segments_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) -> Bool:
        return refine_set_description_at_path_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) -> Bool:
        return refine_set_mandatory_at_path_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) -> Bool:
        return refine_set_default_at_path_impl(
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
        read must_stmt: YangMust,
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) -> Bool:
        return refine_add_must_at_path_impl(
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
        read when_stmt: YangWhen,
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) -> Bool:
        return refine_set_when_at_path_impl(
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
        read type_stmt: YangType,
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) -> Bool:
        return refine_set_type_at_path_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
    ) -> Bool:
        return refine_set_min_elements_at_path_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
    ) -> Bool:
        return refine_set_max_elements_at_path_impl(
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
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
    ) -> Bool:
        return refine_set_ordered_by_at_path_impl(
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
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
    ) -> Bool:
        return refine_set_key_at_path_impl(segments, seg_idx, key, containers, lists)

    def _refine_add_unique_at_path(
        ref self,
        read segments: List[String],
        seg_idx: Int,
        read unique_spec: List[String],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
    ) -> Bool:
        return refine_add_unique_at_path_impl(segments, seg_idx, unique_spec, containers, lists)

    def _split_schema_path(ref self, path: String) -> List[String]:
        return split_schema_path_impl(path)

    def _ident_local_name(ref self, ident: String) -> String:
        return ident_local_name_impl(ident)

    def _clone_must(ref self, read src: YangMust) -> YangMust:
        return clone_must_impl(src)

    def _clone_when(ref self, read src: YangWhen) -> YangWhen:
        return clone_when_impl(src)

    def _clone_yang_type(ref self, read src: YangType) -> YangType:
        return clone_yang_type_impl(src)

    def _clone_leaf_arc(ref self, read src: Arc[YangLeaf]) -> Arc[YangLeaf]:
        return clone_leaf_arc_impl(src)

    def _clone_leaf_list_arc(ref self, read src: Arc[YangLeafList]) -> Arc[YangLeafList]:
        return clone_leaf_list_arc_impl(src)

    def _clone_choice_arc(ref self, read src: Arc[YangChoice]) -> Arc[YangChoice]:
        return clone_choice_arc_impl(src)

    def _clone_anydata_arc(ref self, read src: Arc[YangAnydata]) -> Arc[YangAnydata]:
        return clone_anydata_arc_impl(src)

    def _clone_anyxml_arc(ref self, read src: Arc[YangAnyxml]) -> Arc[YangAnyxml]:
        return clone_anyxml_arc_impl(src)

    def _clone_container_arc(ref self, read src: Arc[YangContainer]) -> Arc[YangContainer]:
        return clone_container_arc_impl(src)

    def _clone_list_arc(ref self, read src: Arc[YangList]) -> Arc[YangList]:
        return clone_list_arc_impl(src)

    def _parse_type_statement(mut self) raises -> YangType:
        return parse_type_statement_impl(self)

    def _parse_must_statement(mut self) raises -> YangMust:
        return parse_must_statement_impl(self)

    def _parse_when_statement(mut self) raises -> YangWhen:
        return parse_when_statement_impl(self)

    def _parse_non_negative_int(mut self, label: String) raises -> Int:
        return parse_non_negative_int_impl(self, label)

    def _parse_ordered_by_argument(mut self) raises -> String:
        return parse_ordered_by_argument_impl(self)

    def _unique_components_from_argument(mut self, arg: String) raises -> List[String]:
        return unique_components_from_argument_impl(arg)

    def _validate_choice_unique_node_names(mut self, read choice: YangChoice) raises:
        validate_choice_unique_node_names_impl(self, choice)

    def _parse_boolean_value(mut self) raises -> Bool:
        return parse_boolean_value_impl(self)

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
            self._error("Expected " + _token_type_name(value) + ", found end of input")
            return
        var got = self._peek()
        if got != value:
            self._error(
                "Expected " + _token_type_name(value) + ", got " + _token_type_name(got),
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
        var out = _token_text(self.source, tok, strip_quotes = tok.type == YangToken.STRING)
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


def _token_text(source: String, read tok: YangToken, strip_quotes: Bool = False) -> String:
    return tok.text(source, strip_quotes = strip_quotes)


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
        if source[byte=i - 1 : i] == "\n":
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
