from std.memory import ArcPointer
import xyang.ast as ast
from xyang.yang.parser.yang_token import (
    YangToken,
    YANG_TYPE_UNKNOWN,
)
from xyang.yang.parser.parser_contract import ParserContract

comptime Arc = ArcPointer
comptime YangContainer = ast.YangContainer
comptime YangList = ast.YangList
comptime YangChoice = ast.YangChoice
comptime YangChoiceCase = ast.YangChoiceCase
comptime YangLeaf = ast.YangLeaf
comptime YangLeafList = ast.YangLeafList
comptime YangAnydata = ast.YangAnydata
comptime YangAnyxml = ast.YangAnyxml
comptime YangType = ast.YangType
comptime YangTypePlain = ast.YangTypePlain
comptime YangMust = ast.YangMust
comptime YangMustStatements = ast.YangMustStatements
comptime YangWhen = ast.YangWhen


def parse_container_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangContainer:
    parser._expect(YangToken.CONTAINER)
    var name = parser._consume_name()

    var desc = ""
    var must = List[Arc[YangMust]]()
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
            if stmt == YangToken.DESCRIPTION:
                parser._consume()
                desc = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YangToken.LEAF:
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
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)

    return YangContainer(
        name = name,
        description = desc,
        must = YangMustStatements(must_statements = must^),
        leaves = leaves^,
        leaf_lists = leaf_lists^,
        anydatas = anydatas^,
        anyxmls = anyxmls^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
    )


def parse_list_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangList:
    parser._expect(YangToken.LIST)
    var name = parser._consume_name()

    var key = ""
    var desc = ""
    var must = List[Arc[YangMust]]()
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

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.KEY:
                parser._consume()
                key = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MIN_ELEMENTS:
                parser._consume()
                min_el = parser._parse_non_negative_int("min-elements")
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MAX_ELEMENTS:
                parser._consume()
                max_el = parser._parse_non_negative_int("max-elements")
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.ORDERED_BY:
                parser._consume()
                ordered_by = parser._parse_ordered_by_argument()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.UNIQUE:
                parser._consume()
                var uarg = parser._consume_argument_value()
                var ucomp = parser._unique_components_from_argument(uarg)
                if len(ucomp) > 0:
                    unique_specs.append(ucomp^)
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.DESCRIPTION:
                parser._consume()
                desc = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YangToken.LEAF:
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
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)

    return YangList(
        name = name,
        key = key,
        description = desc,
        must = YangMustStatements(must_statements = must^),
        children = ast.pack_yang_list_child_buckets(
            ast.YangListChildBuckets(
                leaves = leaves^,
                leaf_lists = leaf_lists^,
                anydatas = anydatas^,
                anyxmls = anyxmls^,
                containers = containers^,
                lists = lists^,
                choices = choices^,
            ),
        ),
        min_elements = min_el,
        max_elements = max_el,
        ordered_by = ordered_by,
        unique_specs = unique_specs^,
    )


def parse_leaf_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangLeaf:
    parser._expect(YangToken.LEAF)
    var name = parser._consume_name()

    var type_stmt = YangType(
        name = YANG_TYPE_UNKNOWN,
        constraints = YangTypePlain(_pad=0),
        union_members = List[Arc[YangType]](),
    )
    var mandatory = False
    var has_default = False
    var default_value = ""
    var description = ""
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.TYPE:
                type_stmt = parser._parse_type_statement()
            elif stmt == YangToken.MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.DEFAULT:
                parser._consume()
                default_value = parser._consume_value()
                while parser._consume_if(YangToken.PLUS):
                    default_value += parser._consume_value()
                has_default = True
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YangToken.WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YangToken.DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)

    return YangLeaf(
        name = name,
        description = description,
        type = type_stmt^,
        mandatory = mandatory,
        has_default = has_default,
        default_value = default_value,
        must = YangMustStatements(must_statements = must^),
        when = when^,
    )


def parse_leaf_list_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangLeafList:
    parser._expect(YangToken.LEAF_LIST)
    var name = parser._consume_name()

    var type_stmt = YangType(
        name = YANG_TYPE_UNKNOWN,
        constraints = YangTypePlain(_pad=0),
        union_members = List[Arc[YangType]](),
    )
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    var description = ""
    var default_values = List[String]()
    var min_el = -1
    var max_el = -1
    var ordered_by = ""

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.TYPE:
                type_stmt = parser._parse_type_statement()
            elif stmt == YangToken.MIN_ELEMENTS:
                parser._consume()
                min_el = parser._parse_non_negative_int("min-elements")
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MAX_ELEMENTS:
                parser._consume()
                max_el = parser._parse_non_negative_int("max-elements")
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.ORDERED_BY:
                parser._consume()
                ordered_by = parser._parse_ordered_by_argument()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.DEFAULT:
                parser._consume()
                default_values.append(parser._consume_argument_value())
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YangToken.WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YangToken.DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)

    return YangLeafList(
        name = name,
        description = description,
        type = type_stmt^,
        default_values = default_values^,
        must = YangMustStatements(must_statements = must^),
        when = when^,
        min_elements = min_el,
        max_elements = max_el,
        ordered_by = ordered_by,
    )


def peek_prefixed_extension_impl[ParserT: ParserContract](read parser: ParserT) -> Bool:
    if not parser._has_more():
        return False
    if parser._peek() == YangToken.COLON:
        return False
    return parser._peek_n(1) == YangToken.COLON


def skip_prefixed_extension_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises:
    _ = parser._consume_value()
    if not parser._consume_if(YangToken.COLON):
        return
    _ = parser._consume_value()
    parser._skip_statement_tail()


def parse_anydata_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangAnydata:
    parser._expect(YangToken.ANYDATA)
    var node_name = parser._consume_name()
    var description = ""
    var mandatory = False
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YangToken.WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YangToken.IF_FEATURE:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_statement_tail()
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)
    return YangAnydata(
        name = node_name,
        description = description^,
        mandatory = mandatory,
        must = YangMustStatements(must_statements = must^),
        when = when^,
    )


def parse_anyxml_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangAnyxml:
    parser._expect(YangToken.ANYXML)
    var node_name = parser._consume_name()
    var description = ""
    var mandatory = False
    var must = List[Arc[YangMust]]()
    var when = Optional[YangWhen]()
    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.DESCRIPTION:
                parser._consume()
                description = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.MUST:
                var m = parser._parse_must_statement()
                must.append(Arc[YangMust](m^))
            elif stmt == YangToken.WHEN:
                var w = parser._parse_when_statement()
                when = Optional(w^)
            elif stmt == YangToken.IF_FEATURE:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_statement_tail()
            elif parser._peek_prefixed_extension():
                parser._skip_prefixed_extension_statement()
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)
    return YangAnyxml(
        name = node_name,
        description = description^,
        mandatory = mandatory,
        must = YangMustStatements(must_statements = must^),
        when = when^,
    )


def parse_choice_statement_impl[ParserT: ParserContract](mut parser: ParserT) raises -> YangChoice:
    parser._expect(YangToken.CHOICE)
    var name = parser._consume_name()

    var mandatory = False
    var default_case = ""
    var choice_when = Optional[YangWhen]()
    var case_names = List[String]()
    var cases = List[Arc[YangChoiceCase]]()

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.MANDATORY:
                parser._consume()
                mandatory = parser._parse_boolean_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.DEFAULT:
                parser._consume()
                default_case = parser._consume_name()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.WHEN:
                var w = parser._parse_when_statement()
                choice_when = Optional(w^)
            elif stmt == YangToken.DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            elif stmt == YangToken.CASE:
                var c = parser._parse_case_statement()
                for i in range(len(c.node_names)):
                    case_names.append(c.node_names[i])
                cases.append(Arc[YangChoiceCase](c^))
            elif stmt == YangToken.LEAF:
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
            elif stmt == YangToken.CONTAINER:
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
            elif stmt == YangToken.LIST:
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
            elif stmt == YangToken.LEAF_LIST:
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
            elif stmt == YangToken.ANYDATA:
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
            elif stmt == YangToken.ANYXML:
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
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)

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
    parser._expect(YangToken.CASE)
    var case_name = parser._consume_name()

    var names = List[String]()
    var case_when = Optional[YangWhen]()

    if parser._consume_if(YangToken.LBRACE):
        while parser._has_more() and parser._peek() != YangToken.RBRACE:
            var stmt = parser._peek()
            if stmt == YangToken.LEAF:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YangToken.CONTAINER:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YangToken.LIST:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YangToken.LEAF_LIST:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YangToken.ANYDATA:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YangToken.ANYXML:
                parser._consume()
                names.append(parser._consume_name())
                parser._skip_statement_tail()
            elif stmt == YangToken.WHEN:
                var w = parser._parse_when_statement()
                case_when = Optional(w^)
            elif stmt == YangToken.DESCRIPTION:
                parser._consume()
                _ = parser._consume_argument_value()
                parser._skip_if(YangToken.SEMICOLON)
            else:
                parser._skip_statement()
        parser._expect(YangToken.RBRACE)
    parser._skip_if(YangToken.SEMICOLON)

    return YangChoiceCase(name=case_name, node_names=names^, when=case_when^)
