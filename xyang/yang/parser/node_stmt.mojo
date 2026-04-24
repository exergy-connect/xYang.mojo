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
    YangTypePlain,
    YangMust,
    YangWhen,
)
from xyang.yang.parser.yang_token import (
    YANG_STMT_CASE,
    YANG_STMT_CHOICE,
    YANG_STMT_CONTAINER,
    YANG_STMT_DEFAULT,
    YANG_STMT_DESCRIPTION,
    YANG_STMT_IF_FEATURE,
    YANG_STMT_KEY,
    YANG_STMT_LEAF,
    YANG_STMT_LEAF_LIST,
    YANG_STMT_ANYDATA,
    YANG_STMT_ANYXML,
    YANG_STMT_LIST,
    YANG_STMT_MANDATORY,
    YANG_STMT_MUST,
    YANG_STMT_TYPE,
    YANG_STMT_USES,
    YANG_STMT_WHEN,
    YANG_STMT_MIN_ELEMENTS,
    YANG_STMT_MAX_ELEMENTS,
    YANG_STMT_ORDERED_BY,
    YANG_STMT_UNIQUE,
    YANG_STMT_AUGMENT,
    YANG_TYPE_UNKNOWN,
)
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer


def parse_container_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangContainer:
    parser._expect(YANG_STMT_CONTAINER)
    var name = parser._consume_name()

    var desc = ""
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
            if stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                desc = parser._consume_argument_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_LEAF:
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
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    return YangContainer(
        name = name,
        description = desc,
        leaves = leaves^,
        leaf_lists = leaf_lists^,
        anydatas = anydatas^,
        anyxmls = anyxmls^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
    )


def parse_list_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangList:
    parser._expect(YANG_STMT_LIST)
    var name = parser._consume_name()

    var key = ""
    var desc = ""
    var min_el = -1
    var max_el = -1
    var ordered_by = ""
    var unique_specs = List[List[String]]()
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
            if stmt == YANG_STMT_KEY:
                parser._consume()
                key = parser._consume_argument_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_MIN_ELEMENTS:
                parser._consume()
                min_el = parser._parse_non_negative_int("min-elements")
                parser._skip_if(";")
            elif stmt == YANG_STMT_MAX_ELEMENTS:
                parser._consume()
                max_el = parser._parse_non_negative_int("max-elements")
                parser._skip_if(";")
            elif stmt == YANG_STMT_ORDERED_BY:
                parser._consume()
                ordered_by = parser._parse_ordered_by_argument()
                parser._skip_if(";")
            elif stmt == YANG_STMT_UNIQUE:
                parser._consume()
                var uarg = parser._consume_argument_value()
                var ucomp = parser._unique_components_from_argument(uarg)
                if len(ucomp) > 0:
                    unique_specs.append(ucomp^)
                parser._skip_if(";")
            elif stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                desc = parser._consume_argument_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_LEAF:
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
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    return YangList(
        name = name,
        key = key,
        description = desc,
        leaves = leaves^,
        leaf_lists = leaf_lists^,
        anydatas = anydatas^,
        anyxmls = anyxmls^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
        min_elements = min_el,
        max_elements = max_el,
        ordered_by = ordered_by,
        unique_specs = unique_specs^,
    )


def parse_leaf_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangLeaf:
    parser._expect(YANG_STMT_LEAF)
    var name = parser._consume_name()

    var type_stmt = YangType(
        name = YANG_TYPE_UNKNOWN,
        constraints = YangTypePlain(_pad=0),
        union_members = List[Arc[YangType]](),
    )
    var mandatory = False
    var has_default = False
    var default_value = ""
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_TYPE:
                type_stmt = parser._parse_type_statement()
            elif stmt == YANG_STMT_MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_DEFAULT:
                parser._consume()
                default_value = parser._consume_value()
                while parser._consume_if("+"):
                    default_value += parser._consume_value()
                has_default = True
                parser._skip_if(";")
            elif stmt == YANG_STMT_MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YANG_STMT_WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(";")
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    return YangLeaf(
        name = name,
        type = type_stmt^,
        mandatory = mandatory,
        has_default = has_default,
        default_value = default_value,
        must_statements = must^,
        when = when^,
    )


def parse_leaf_list_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangLeafList:
    parser._expect(YANG_STMT_LEAF_LIST)
    var name = parser._consume_name()

    var type_stmt = YangType(
        name = YANG_TYPE_UNKNOWN,
        constraints = YangTypePlain(_pad=0),
        union_members = List[Arc[YangType]](),
    )
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    var default_values = List[String]()
    var min_el = -1
    var max_el = -1
    var ordered_by = ""

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_TYPE:
                type_stmt = parser._parse_type_statement()
            elif stmt == YANG_STMT_MIN_ELEMENTS:
                parser._consume()
                min_el = parser._parse_non_negative_int("min-elements")
                parser._skip_if(";")
            elif stmt == YANG_STMT_MAX_ELEMENTS:
                parser._consume()
                max_el = parser._parse_non_negative_int("max-elements")
                parser._skip_if(";")
            elif stmt == YANG_STMT_ORDERED_BY:
                parser._consume()
                ordered_by = parser._parse_ordered_by_argument()
                parser._skip_if(";")
            elif stmt == YANG_STMT_DEFAULT:
                parser._consume()
                default_values.append(parser._consume_argument_value())
                parser._skip_if(";")
            elif stmt == YANG_STMT_MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YANG_STMT_WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(";")
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    return YangLeafList(
        name = name,
        type = type_stmt^,
        default_values = default_values^,
        must_statements = must^,
        when = when^,
        min_elements = min_el,
        max_elements = max_el,
        ordered_by = ordered_by,
    )


def peek_prefixed_extension_impl[ParserT: ParserContract](read parser: ParserT) -> Bool:
    if not parser._has_more():
        return False
    if parser._peek() == ":":
        return False
    return parser._peek_n(1) == ":"


def skip_prefixed_extension_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    _ = parser._consume_value()
    if not parser._consume_if(":"):
        return
    _ = parser._consume_value()
    parser._skip_statement_tail()


def parse_anydata_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangAnydata:
    parser._expect(YANG_STMT_ANYDATA)
    var node_name = parser._consume_name()
    var description = ""
    var mandatory = False
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YANG_STMT_WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YANG_STMT_IF_FEATURE:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_statement_tail()
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")
    return YangAnydata(
        name = node_name,
        description = description^,
        mandatory = mandatory,
        must_statements = must^,
        when = when^,
    )


def parse_anyxml_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangAnyxml:
    parser._expect(YANG_STMT_ANYXML)
    var node_name = parser._consume_name()
    var description = ""
    var mandatory = False
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YANG_STMT_WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YANG_STMT_IF_FEATURE:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_statement_tail()
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")
    return YangAnyxml(
        name = node_name,
        description = description^,
        mandatory = mandatory,
        must_statements = must^,
        when = when^,
    )


def parse_choice_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangChoice:
    parser._expect(YANG_STMT_CHOICE)
    var name = parser._consume_name()

    var mandatory = False
    var default_case = ""
    var choice_when = Optional[YangWhen]()
    var case_names = List[String]()
    var cases = List[Arc[YangChoiceCase]]()

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_DEFAULT:
                parser._consume()
                default_case = parser._consume_name()
                parser._skip_if(";")
            elif stmt == YANG_STMT_WHEN:
                var w = parser._parse_when_statement()
                choice_when = Optional(w^)
            elif stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(";")
            elif stmt == YANG_STMT_CASE:
                var c = parser._parse_case_statement()
                for i in range(len(c.node_names)):
                    case_names.append(c.node_names[i])
                cases.append(Arc[YangChoiceCase](c^))
            elif stmt == YANG_STMT_LEAF:
                parser._consume()
                var node_name = parser._consume_name()
                case_names.append(node_name)
                var implicit_names = List[String]()
                implicit_names.append(node_name)
                cases.append(Arc[YangChoiceCase](
                    YangChoiceCase(
                        name=node_name,
                        node_names=implicit_names^,
                        when=Optional[YangWhen](),
                    ),
                ))
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_CONTAINER:
                parser._consume()
                var node_name = parser._consume_name()
                case_names.append(node_name)
                var implicit_names = List[String]()
                implicit_names.append(node_name)
                cases.append(Arc[YangChoiceCase](
                    YangChoiceCase(
                        name=node_name,
                        node_names=implicit_names^,
                        when=Optional[YangWhen](),
                    ),
                ))
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_LIST:
                parser._consume()
                var node_name = parser._consume_name()
                case_names.append(node_name)
                var implicit_names = List[String]()
                implicit_names.append(node_name)
                cases.append(Arc[YangChoiceCase](
                    YangChoiceCase(
                        name=node_name,
                        node_names=implicit_names^,
                        when=Optional[YangWhen](),
                    ),
                ))
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_LEAF_LIST:
                parser._consume()
                var node_name = parser._consume_name()
                case_names.append(node_name)
                var implicit_names = List[String]()
                implicit_names.append(node_name)
                cases.append(Arc[YangChoiceCase](
                    YangChoiceCase(
                        name=node_name,
                        node_names=implicit_names^,
                        when=Optional[YangWhen](),
                    ),
                ))
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_ANYDATA:
                parser._consume()
                var node_name = parser._consume_name()
                case_names.append(node_name)
                var implicit_names = List[String]()
                implicit_names.append(node_name)
                cases.append(Arc[YangChoiceCase](
                    YangChoiceCase(
                        name=node_name,
                        node_names=implicit_names^,
                        when=Optional[YangWhen](),
                    ),
                ))
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_ANYXML:
                parser._consume()
                var node_name = parser._consume_name()
                case_names.append(node_name)
                var implicit_names = List[String]()
                implicit_names.append(node_name)
                cases.append(Arc[YangChoiceCase](
                    YangChoiceCase(
                        name=node_name,
                        node_names=implicit_names^,
                        when=Optional[YangWhen](),
                    ),
                ))
                parser._skip_statement_tail()
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    var built = YangChoice(
        name = name,
        mandatory = mandatory,
        default_case = default_case,
        case_names = case_names^,
        cases = cases^,
        when = choice_when^,
    )
    if len(built.cases) > 0:
        parser._validate_choice_unique_node_names(built)
    return built^


def parse_case_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangChoiceCase:
    parser._expect(YANG_STMT_CASE)
    var case_name = parser._consume_name()

    var names = List[String]()
    var case_when = Optional[YangWhen]()

    if parser._consume_if("{"):
        while parser._has_more() and parser._peek() != "}":
            var stmt = parser._peek()
            if stmt == YANG_STMT_LEAF:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_CONTAINER:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_LIST:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_LEAF_LIST:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_ANYDATA:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_ANYXML:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YANG_STMT_WHEN:
                var w = parser._parse_when_statement()
                case_when = Optional(w^)
            elif stmt == YANG_STMT_DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(";")
            else:
                parser._skip_statement()
        parser._expect("}")
    parser._skip_if(";")

    return YangChoiceCase(name=case_name, node_names=names^, when=case_when^)
