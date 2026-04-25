from std.memory import ArcPointer
from xyang.ast import (
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
)
from xyang.yang.parser.types import ParsedGrouping
from xyang.yang.parser.parsed_augment import ParsedAugment
from xyang.yang.parser.yang_token import YangToken

comptime Arc = ArcPointer


trait ParserContract:
    def _prime_groupings_for_current_module_body(mut self) raises:
        ...

    def _expect(mut self, value: YangToken.Type) raises:
        ...

    def _consume_name(mut self) raises -> String:
        ...

    def _consume_if(mut self, value: YangToken.Type) -> Bool:
        ...

    def _skip_if(mut self, value: YangToken.Type):
        ...

    def _has_more(ref self) -> Bool:
        ...

    def _peek(ref self) -> YangToken.Type:
        ...

    def _peek_n(ref self, offset: Int) -> YangToken.Type:
        ...

    def _peek_value(ref self) -> String:
        ...

    def _peek_value_n(ref self, offset: Int) -> String:
        ...

    def _consume(mut self) raises:
        ...

    def _consume_value(mut self) raises -> String:
        ...

    def _consume_argument_value(mut self) raises -> String:
        ...

    def _skip_block_body(mut self) raises:
        ...

    def _skip_statement(mut self) raises:
        ...

    def _skip_statement_tail(mut self) raises:
        ...

    def _parse_container_statement(mut self) raises -> YangContainer:
        ...

    def _parse_grouping_statement(mut self) raises:
        ...

    def _store_grouping(mut self, var grouping: ParsedGrouping) raises:
        ...

    def _parse_module_augment_statement(
        mut self,
        mut top_containers: List[Arc[YangContainer]],
    ) raises:
        ...

    def _apply_pending_module_augments(
        mut self,
        mut top_containers: List[Arc[YangContainer]],
    ) raises:
        ...

    def _queue_pending_module_augment(mut self, var aug: ParsedAugment):
        ...

    def _parse_leaf_statement(mut self) raises -> YangLeaf:
        ...

    def _parse_leaf_list_statement(mut self) raises -> YangLeafList:
        ...

    def _parse_anydata_statement(mut self) raises -> YangAnydata:
        ...

    def _parse_anyxml_statement(mut self) raises -> YangAnyxml:
        ...

    def _parse_list_statement(mut self) raises -> YangList:
        ...

    def _parse_choice_statement(mut self) raises -> YangChoice:
        ...

    def _parse_case_statement(mut self) raises -> YangChoiceCase:
        ...

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
        ...

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
        ...

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
        ...

    def _parse_if_feature_statement(mut self) raises:
        ...

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
        ...

    def _peek_prefixed_extension(ref self) -> Bool:
        ...

    def _skip_prefixed_extension_statement(mut self) raises:
        ...

    def _parse_type_statement(mut self) raises -> YangType:
        ...

    def _parse_boolean_value(mut self) raises -> Bool:
        ...

    def _parse_non_negative_int(mut self, label: String) raises -> Int:
        ...

    def _parse_ordered_by_argument(mut self) raises -> String:
        ...

    def _unique_components_from_argument(mut self, arg: String) raises -> List[String]:
        ...

    def _parse_must_statement(mut self) raises -> YangMust:
        ...

    def _parse_when_statement(mut self) raises -> YangWhen:
        ...

    def _validate_choice_unique_node_names(mut self, read choice: YangChoice) raises:
        ...

    def _error(ref self, message: String) raises:
        ...
