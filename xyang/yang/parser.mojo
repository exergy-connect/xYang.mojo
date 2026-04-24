## Text YANG parser for Mojo AST (modeled after Python xYang parser flow).
##
## Supported subset:
## - module header: module, namespace, prefix, description, revision (list, body skipped)
## - data nodes: container, list, leaf, choice/case
## - leaf/list details: type, mandatory, key
## - must on leaves with optional error-message/description block

from std.collections import Dict
from std.collections.string import Codepoint
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
    YangTypePlain,
    YangTypeIntegerRange,
    YangTypeDecimal64,
    YangTypeEnumeration,
    YangTypeLeafref,
    YangTypeBits,
    YangTypeIdentityref,
    YangMust,
    YangWhen,
)
from xyang.xpath import parse_xpath, Expr
from xyang.yang.tokens import (
    YANG_BOOL_FALSE,
    YANG_BOOL_TRUE,
    YANG_STMT_CASE,
    YANG_STMT_CHOICE,
    YANG_STMT_CONTACT,
    YANG_STMT_CONTAINER,
    YANG_STMT_DEFAULT,
    YANG_STMT_DESCRIPTION,
    YANG_STMT_ERROR_MESSAGE,
    YANG_STMT_ENUM,
    YANG_STMT_IF_FEATURE,
    YANG_STMT_GROUPING,
    YANG_STMT_KEY,
    YANG_STMT_LEAF,
    YANG_STMT_LEAF_LIST,
    YANG_STMT_ANYDATA,
    YANG_STMT_ANYXML,
    YANG_STMT_LIST,
    YANG_STMT_MANDATORY,
    YANG_STMT_MODULE,
    YANG_STMT_MUST,
    YANG_STMT_NAMESPACE,
    YANG_STMT_ORGANIZATION,
    YANG_STMT_PATH,
    YANG_STMT_PREFIX,
    YANG_STMT_RANGE,
    YANG_STMT_FRACTION_DIGITS,
    YANG_STMT_BIT,
    YANG_STMT_BASE,
    YANG_STMT_REQUIRE_INSTANCE,
    YANG_STMT_REVISION,
    YANG_STMT_AUGMENT,
    YANG_STMT_REFINE,
    YANG_STMT_TYPE,
    YANG_STMT_UNION,
    YANG_STMT_USES,
    YANG_STMT_WHEN,
    YANG_STMT_MIN_ELEMENTS,
    YANG_STMT_MAX_ELEMENTS,
    YANG_STMT_ORDERED_BY,
    YANG_STMT_UNIQUE,
    YANG_TYPE_ENUMERATION,
    YANG_TYPE_LEAFREF,
    YANG_TYPE_UNKNOWN,
)

comptime Arc = ArcPointer


def _yang_constraints_for_parsed_type(
    type_name: String,
    has_range: Bool,
    range_min: Int64,
    range_max: Int64,
    var enum_values: List[String],
    has_leafref_path: Bool,
    var leafref_path: String,
    leafref_require_instance: Bool,
    var leafref_xpath_ast: Expr.ExprPointer,
    leafref_path_parsed: Bool,
    fraction_digits: Int,
    has_dec_range: Bool,
    dec_lo: Float64,
    dec_hi: Float64,
    var bits_names: List[String],
    var identityref_base: String,
) -> YangType.Constraints:
    if type_name == YANG_TYPE_ENUMERATION:
        return YangTypeEnumeration(enum_values^)
    if type_name == "decimal64":
        return YangTypeDecimal64(
            fraction_digits,
            has_dec_range,
            dec_lo,
            dec_hi,
        )
    if type_name == YANG_TYPE_LEAFREF:
        return YangTypeLeafref(
            has_leafref_path,
            leafref_path^,
            leafref_require_instance,
            leafref_xpath_ast,
            leafref_path_parsed,
        )
    if type_name == "bits":
        return YangTypeBits(bits_names^)
    if type_name == "identityref":
        return YangTypeIdentityref(identityref_base^)
    if (
        type_name == "integer"
        or type_name == "int8"
        or type_name == "int16"
        or type_name == "int32"
        or type_name == "int64"
        or type_name == "uint8"
        or type_name == "uint16"
        or type_name == "uint32"
        or type_name == "uint64"
        or type_name == "number"
    ):
        return YangTypeIntegerRange(has_range, range_min, range_max)
    return YangTypePlain(_pad=0)
comptime CP_NEWLINE = Codepoint.ord("\n")
comptime CP_SLASH = Codepoint.ord("/")
comptime CP_STAR = Codepoint.ord("*")
comptime CP_DQUOTE = Codepoint.ord('"')
comptime CP_SQUOTE = Codepoint.ord("'")
comptime CP_BACKSLASH = Codepoint.ord("\\")
comptime CP_BRACE_OPEN = Codepoint.ord("{")
comptime CP_BRACE_CLOSE = Codepoint.ord("}")
comptime CP_SEMICOLON = Codepoint.ord(";")
comptime CP_COLON = Codepoint.ord(":")
comptime CP_PLUS = Codepoint.ord("+")


@fieldwise_init
struct YangToken(Copyable, Movable):
    var value: String
    var quoted: Bool
    var line: Int
    var col: Int


@fieldwise_init
struct ParsedGrouping(Movable):
    var name: String
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var anydatas: List[Arc[YangAnydata]]
    var anyxmls: List[Arc[YangAnyxml]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]


@fieldwise_init
struct ParsedAugment(Movable):
    var path: String
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var anydatas: List[Arc[YangAnydata]]
    var anyxmls: List[Arc[YangAnyxml]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]


struct _YangParser(Movable):
    var tokens: List[YangToken]
    var index: Int
    var grouping_names: List[String]
    var groupings: List[Arc[ParsedGrouping]]
    var pending_module_augments: List[Arc[ParsedAugment]]

    def __init__(out self, var tokens: List[YangToken]):
        self.tokens = tokens^
        self.index = 0
        self.grouping_names = List[String]()
        self.groupings = List[Arc[ParsedGrouping]]()
        self.pending_module_augments = List[Arc[ParsedAugment]]()

    def parse_module(mut self) raises -> YangModule:
        self._expect(YANG_STMT_MODULE)
        var module_name = self._consume_name()
        self._expect("{")

        var namespace = ""
        var prefix = ""
        var description = ""
        var revisions = List[String]()
        var organization = ""
        var contact = ""
        var top_containers = List[Arc[YangContainer]]()

        while self._has_more() and self._peek() != "}":
            var stmt = self._peek()
            if stmt == YANG_STMT_NAMESPACE:
                self._consume()
                namespace = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == YANG_STMT_PREFIX:
                self._consume()
                prefix = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == YANG_STMT_DESCRIPTION:
                self._consume()
                description = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == YANG_STMT_REVISION:
                self._consume()
                revisions.append(self._consume_argument_value())
                if self._consume_if("{"):
                    self._skip_block_body()
                self._skip_if(";")
            elif stmt == YANG_STMT_ORGANIZATION:
                self._consume()
                organization = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == YANG_STMT_CONTACT:
                self._consume()
                contact = self._consume_argument_value()
                self._skip_if(";")
            elif stmt == YANG_STMT_CONTAINER:
                var c = self._parse_container_statement()
                top_containers.append(Arc[YangContainer](c^))
            elif stmt == YANG_STMT_GROUPING:
                self._parse_grouping_statement()
            elif stmt == YANG_STMT_AUGMENT:
                self._parse_module_augment_statement(top_containers)
            else:
                self._skip_statement()

        self._expect("}")
        self._skip_if(";")
        self._apply_pending_module_augments(top_containers)

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

    def _parse_container_statement(mut self) raises -> YangContainer:
        self._expect(YANG_STMT_CONTAINER)
        var name = self._consume_name()

        var desc = ""
        var leaves = List[Arc[YangLeaf]]()
        var leaf_lists = List[Arc[YangLeafList]]()
        var anydatas = List[Arc[YangAnydata]]()
        var anyxmls = List[Arc[YangAnyxml]]()
        var containers = List[Arc[YangContainer]]()
        var lists = List[Arc[YangList]]()
        var choices = List[Arc[YangChoice]]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    desc = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_LEAF:
                    var leaf = self._parse_leaf_statement()
                    leaves.append(Arc[YangLeaf](leaf^))
                elif stmt == YANG_STMT_LEAF_LIST:
                    var leaf_list = self._parse_leaf_list_statement()
                    leaf_lists.append(Arc[YangLeafList](leaf_list^))
                elif stmt == YANG_STMT_ANYDATA:
                    var ad = self._parse_anydata_statement()
                    anydatas.append(Arc[YangAnydata](ad^))
                elif stmt == YANG_STMT_ANYXML:
                    var ax = self._parse_anyxml_statement()
                    anyxmls.append(Arc[YangAnyxml](ax^))
                elif stmt == YANG_STMT_CONTAINER:
                    var child_container = self._parse_container_statement()
                    containers.append(Arc[YangContainer](child_container^))
                elif stmt == YANG_STMT_LIST:
                    var child_list = self._parse_list_statement()
                    lists.append(Arc[YangList](child_list^))
                elif stmt == YANG_STMT_CHOICE:
                    var choice = self._parse_choice_statement()
                    choices.append(Arc[YangChoice](choice^))
                elif stmt == YANG_STMT_USES:
                    self._parse_uses_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif stmt == YANG_STMT_AUGMENT:
                    self._parse_relative_augment_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif self._peek_prefixed_extension():
                    self._skip_prefixed_extension_statement()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

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

    def _parse_list_statement(mut self) raises -> YangList:
        self._expect(YANG_STMT_LIST)
        var name = self._consume_name()

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

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_KEY:
                    self._consume()
                    key = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_MIN_ELEMENTS:
                    self._consume()
                    min_el = self._parse_non_negative_int("min-elements")
                    self._skip_if(";")
                elif stmt == YANG_STMT_MAX_ELEMENTS:
                    self._consume()
                    max_el = self._parse_non_negative_int("max-elements")
                    self._skip_if(";")
                elif stmt == YANG_STMT_ORDERED_BY:
                    self._consume()
                    ordered_by = self._parse_ordered_by_argument()
                    self._skip_if(";")
                elif stmt == YANG_STMT_UNIQUE:
                    self._consume()
                    var uarg = self._consume_argument_value()
                    var ucomp = self._unique_components_from_argument(uarg)
                    if len(ucomp) > 0:
                        unique_specs.append(ucomp^)
                    self._skip_if(";")
                elif stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    desc = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_LEAF:
                    var leaf = self._parse_leaf_statement()
                    leaves.append(Arc[YangLeaf](leaf^))
                elif stmt == YANG_STMT_LEAF_LIST:
                    var leaf_list = self._parse_leaf_list_statement()
                    leaf_lists.append(Arc[YangLeafList](leaf_list^))
                elif stmt == YANG_STMT_ANYDATA:
                    var ad = self._parse_anydata_statement()
                    anydatas.append(Arc[YangAnydata](ad^))
                elif stmt == YANG_STMT_ANYXML:
                    var ax = self._parse_anyxml_statement()
                    anyxmls.append(Arc[YangAnyxml](ax^))
                elif stmt == YANG_STMT_CONTAINER:
                    var child_container = self._parse_container_statement()
                    containers.append(Arc[YangContainer](child_container^))
                elif stmt == YANG_STMT_LIST:
                    var child_list = self._parse_list_statement()
                    lists.append(Arc[YangList](child_list^))
                elif stmt == YANG_STMT_CHOICE:
                    var choice = self._parse_choice_statement()
                    choices.append(Arc[YangChoice](choice^))
                elif stmt == YANG_STMT_USES:
                    self._parse_uses_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif stmt == YANG_STMT_AUGMENT:
                    self._parse_relative_augment_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif self._peek_prefixed_extension():
                    self._skip_prefixed_extension_statement()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

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

    def _parse_leaf_statement(mut self) raises -> YangLeaf:
        self._expect(YANG_STMT_LEAF)
        var name = self._consume_name()

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

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_TYPE:
                    type_stmt = self._parse_type_statement()
                elif stmt == YANG_STMT_MANDATORY:
                    self._consume()
                    mandatory = self._parse_boolean_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_DEFAULT:
                    self._consume()
                    default_value = self._consume_value()
                    while self._consume_if("+"):
                        default_value += self._consume_value()
                    has_default = True
                    self._skip_if(";")
                elif stmt == YANG_STMT_MUST:
                    var m = self._parse_must_statement()
                    must.append(Arc[YangMust](m^))
                elif stmt == YANG_STMT_WHEN:
                    var w = self._parse_when_statement()
                    when = Optional(w^)
                elif stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangLeaf(
            name = name,
            type = type_stmt^,
            mandatory = mandatory,
            has_default = has_default,
            default_value = default_value,
            must_statements = must^,
            when = when^,
        )

    def _parse_leaf_list_statement(mut self) raises -> YangLeafList:
        self._expect(YANG_STMT_LEAF_LIST)
        var name = self._consume_name()

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

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_TYPE:
                    type_stmt = self._parse_type_statement()
                elif stmt == YANG_STMT_MIN_ELEMENTS:
                    self._consume()
                    min_el = self._parse_non_negative_int("min-elements")
                    self._skip_if(";")
                elif stmt == YANG_STMT_MAX_ELEMENTS:
                    self._consume()
                    max_el = self._parse_non_negative_int("max-elements")
                    self._skip_if(";")
                elif stmt == YANG_STMT_ORDERED_BY:
                    self._consume()
                    ordered_by = self._parse_ordered_by_argument()
                    self._skip_if(";")
                elif stmt == YANG_STMT_DEFAULT:
                    self._consume()
                    default_values.append(self._consume_argument_value())
                    self._skip_if(";")
                elif stmt == YANG_STMT_MUST:
                    var m = self._parse_must_statement()
                    must.append(Arc[YangMust](m^))
                elif stmt == YANG_STMT_WHEN:
                    var w = self._parse_when_statement()
                    when = Optional(w^)
                elif stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

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

    def _peek_prefixed_extension(ref self) -> Bool:
        ## True when the next statement looks like `prefix:extension-name ...` (RFC 7950 extension).
        if self.index + 2 >= len(self.tokens):
            return False
        return self.tokens[self.index + 1].value == ":"

    def _skip_prefixed_extension_statement(mut self) raises:
        _ = self._consume_value()
        if not self._consume_if(":"):
            return
        _ = self._consume_value()
        self._skip_statement_tail()

    def _parse_anydata_statement(mut self) raises -> YangAnydata:
        self._expect(YANG_STMT_ANYDATA)
        var node_name = self._consume_name()
        var description = ""
        var mandatory = False
        var must = List[Arc[YangMust]]()
        var when = Optional[YangWhen]()
        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    description = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_MANDATORY:
                    self._consume()
                    mandatory = self._parse_boolean_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_MUST:
                    var m = self._parse_must_statement()
                    must.append(Arc[YangMust](m^))
                elif stmt == YANG_STMT_WHEN:
                    var w = self._parse_when_statement()
                    when = Optional(w^)
                elif stmt == YANG_STMT_IF_FEATURE:
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_statement_tail()
                elif self._peek_prefixed_extension():
                    self._skip_prefixed_extension_statement()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")
        return YangAnydata(
            name = node_name,
            description = description^,
            mandatory = mandatory,
            must_statements = must^,
            when = when^,
        )

    def _parse_anyxml_statement(mut self) raises -> YangAnyxml:
        self._expect(YANG_STMT_ANYXML)
        var node_name = self._consume_name()
        var description = ""
        var mandatory = False
        var must = List[Arc[YangMust]]()
        var when = Optional[YangWhen]()
        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    description = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_MANDATORY:
                    self._consume()
                    mandatory = self._parse_boolean_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_MUST:
                    var m = self._parse_must_statement()
                    must.append(Arc[YangMust](m^))
                elif stmt == YANG_STMT_WHEN:
                    var w = self._parse_when_statement()
                    when = Optional(w^)
                elif stmt == YANG_STMT_IF_FEATURE:
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_statement_tail()
                elif self._peek_prefixed_extension():
                    self._skip_prefixed_extension_statement()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")
        return YangAnyxml(
            name = node_name,
            description = description^,
            mandatory = mandatory,
            must_statements = must^,
            when = when^,
        )

    def _parse_choice_statement(mut self) raises -> YangChoice:
        self._expect(YANG_STMT_CHOICE)
        var name = self._consume_name()

        var mandatory = False
        var default_case = ""
        var choice_when = Optional[YangWhen]()
        var case_names = List[String]()
        var cases = List[Arc[YangChoiceCase]]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_MANDATORY:
                    self._consume()
                    mandatory = self._parse_boolean_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_DEFAULT:
                    self._consume()
                    default_case = self._consume_name()
                    self._skip_if(";")
                elif stmt == YANG_STMT_WHEN:
                    var w = self._parse_when_statement()
                    choice_when = Optional(w^)
                elif stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_CASE:
                    var c = self._parse_case_statement()
                    for i in range(len(c.node_names)):
                        case_names.append(c.node_names[i])
                    cases.append(Arc[YangChoiceCase](c^))
                elif stmt == YANG_STMT_LEAF:
                    self._consume()
                    var node_name = self._consume_name()
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
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_CONTAINER:
                    self._consume()
                    var node_name = self._consume_name()
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
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_LIST:
                    self._consume()
                    var node_name = self._consume_name()
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
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_LEAF_LIST:
                    self._consume()
                    var node_name = self._consume_name()
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
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_ANYDATA:
                    self._consume()
                    var node_name = self._consume_name()
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
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_ANYXML:
                    self._consume()
                    var node_name = self._consume_name()
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
                    self._skip_statement_tail()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        var built = YangChoice(
            name = name,
            mandatory = mandatory,
            default_case = default_case,
            case_names = case_names^,
            cases = cases^,
            when = choice_when^,
        )
        if len(built.cases) > 0:
            self._validate_choice_unique_node_names(built)
        return built^

    def _parse_case_statement(mut self) raises -> YangChoiceCase:
        self._expect(YANG_STMT_CASE)
        var case_name = self._consume_name()

        var names = List[String]()
        var case_when = Optional[YangWhen]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_LEAF:
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_CONTAINER:
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_LIST:
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_LEAF_LIST:
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_ANYDATA:
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_ANYXML:
                    self._consume()
                    names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_WHEN:
                    var w = self._parse_when_statement()
                    case_when = Optional(w^)
                elif stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangChoiceCase(name=case_name, node_names=names^, when=case_when^)

    def _parse_grouping_statement(mut self) raises:
        self._expect(YANG_STMT_GROUPING)
        var name = self._consume_name()

        var leaves = List[Arc[YangLeaf]]()
        var leaf_lists = List[Arc[YangLeafList]]()
        var anydatas = List[Arc[YangAnydata]]()
        var anyxmls = List[Arc[YangAnyxml]]()
        var containers = List[Arc[YangContainer]]()
        var lists = List[Arc[YangList]]()
        var choices = List[Arc[YangChoice]]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_LEAF:
                    var leaf = self._parse_leaf_statement()
                    leaves.append(Arc[YangLeaf](leaf^))
                elif stmt == YANG_STMT_LEAF_LIST:
                    var leaf_list = self._parse_leaf_list_statement()
                    leaf_lists.append(Arc[YangLeafList](leaf_list^))
                elif stmt == YANG_STMT_ANYDATA:
                    var ad = self._parse_anydata_statement()
                    anydatas.append(Arc[YangAnydata](ad^))
                elif stmt == YANG_STMT_ANYXML:
                    var ax = self._parse_anyxml_statement()
                    anyxmls.append(Arc[YangAnyxml](ax^))
                elif stmt == YANG_STMT_CONTAINER:
                    var child_container = self._parse_container_statement()
                    containers.append(Arc[YangContainer](child_container^))
                elif stmt == YANG_STMT_LIST:
                    var child_list = self._parse_list_statement()
                    lists.append(Arc[YangList](child_list^))
                elif stmt == YANG_STMT_CHOICE:
                    var choice = self._parse_choice_statement()
                    choices.append(Arc[YangChoice](choice^))
                elif stmt == YANG_STMT_USES:
                    self._parse_uses_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif stmt == YANG_STMT_AUGMENT:
                    self._parse_relative_augment_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    _ = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        self._store_grouping(
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

    def _store_grouping(mut self, var grouping: ParsedGrouping) raises:
        for i in range(len(self.grouping_names)):
            if self.grouping_names[i] == grouping.name:
                self._error("Duplicate grouping '" + grouping.name + "'")
                return
        self.grouping_names.append(grouping.name)
        self.groupings.append(Arc[ParsedGrouping](grouping^))

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
        self._expect(YANG_STMT_USES)
        var grouping_name = self._consume_name()
        self._append_grouping_nodes_by_name(
            grouping_name,
            leaves,
            leaf_lists,
            anydatas,
            anyxmls,
            containers,
            lists,
            choices,
        )
        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_IF_FEATURE:
                    self._parse_if_feature_statement()
                elif stmt == YANG_STMT_REFINE:
                    self._parse_refine_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif stmt == YANG_STMT_AUGMENT:
                    self._parse_relative_augment_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

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
        var idx = self._find_grouping_index(grouping_name)
        if idx < 0:
            self._error("Unknown grouping '" + grouping_name + "' in uses statement")
            return
        for i in range(len(self.groupings[idx][].leaves)):
            var leaf_src = self.groupings[idx][].leaves[i].copy()
            leaves.append(self._clone_leaf_arc(leaf_src))
        for i in range(len(self.groupings[idx][].leaf_lists)):
            var ll_src = self.groupings[idx][].leaf_lists[i].copy()
            leaf_lists.append(self._clone_leaf_list_arc(ll_src))
        for i in range(len(self.groupings[idx][].anydatas)):
            var ad_src = self.groupings[idx][].anydatas[i].copy()
            anydatas.append(self._clone_anydata_arc(ad_src))
        for i in range(len(self.groupings[idx][].anyxmls)):
            var ax_src = self.groupings[idx][].anyxmls[i].copy()
            anyxmls.append(self._clone_anyxml_arc(ax_src))
        for i in range(len(self.groupings[idx][].containers)):
            var c_src = self.groupings[idx][].containers[i].copy()
            containers.append(self._clone_container_arc(c_src))
        for i in range(len(self.groupings[idx][].lists)):
            var l_src = self.groupings[idx][].lists[i].copy()
            lists.append(self._clone_list_arc(l_src))
        for i in range(len(self.groupings[idx][].choices)):
            var ch_src = self.groupings[idx][].choices[i].copy()
            choices.append(self._clone_choice_arc(ch_src))

    def _find_grouping_index(ref self, grouping_name: String) -> Int:
        for i in range(len(self.grouping_names)):
            if self.grouping_names[i] == grouping_name:
                return i
        return -1

    def _parse_if_feature_statement(mut self) raises:
        self._expect(YANG_STMT_IF_FEATURE)
        _ = self._consume_argument_value()
        self._skip_if(";")

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
        _ = anydatas
        _ = anyxmls
        self._expect(YANG_STMT_REFINE)
        var refine_path = self._consume_argument_value()
        var segments = self._split_schema_path(refine_path)
        if len(segments) == 0:
            self._error("refine requires a descendant schema-node identifier")
            self._skip_statement_tail()
            return

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    var desc = self._consume_argument_value()
                    self._skip_if(";")
                    if not self._refine_set_description_at_path(
                        segments,
                        0,
                        desc,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                        choices,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_MANDATORY:
                    self._consume()
                    var mandatory = self._parse_boolean_value()
                    self._skip_if(";")
                    if not self._refine_set_mandatory_at_path(
                        segments,
                        0,
                        mandatory,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                        choices,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_DEFAULT:
                    self._consume()
                    var default_value = self._consume_argument_value()
                    self._skip_if(";")
                    if not self._refine_set_default_at_path(
                        segments,
                        0,
                        default_value,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                        choices,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_MUST:
                    var must_stmt = self._parse_must_statement()
                    if not self._refine_add_must_at_path(
                        segments,
                        0,
                        must_stmt,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                        choices,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_WHEN:
                    var when_stmt = self._parse_when_statement()
                    if not self._refine_set_when_at_path(
                        segments,
                        0,
                        when_stmt,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                        choices,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_TYPE:
                    var type_stmt = self._parse_type_statement()
                    if not self._refine_set_type_at_path(
                        segments,
                        0,
                        type_stmt,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                        choices,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_MIN_ELEMENTS:
                    self._consume()
                    var min_el = self._parse_non_negative_int("min-elements")
                    self._skip_if(";")
                    if not self._refine_set_min_elements_at_path(
                        segments,
                        0,
                        min_el,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_MAX_ELEMENTS:
                    self._consume()
                    var max_el = self._parse_non_negative_int("max-elements")
                    self._skip_if(";")
                    if not self._refine_set_max_elements_at_path(
                        segments,
                        0,
                        max_el,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_ORDERED_BY:
                    self._consume()
                    var ordered_by = self._parse_ordered_by_argument()
                    self._skip_if(";")
                    if not self._refine_set_ordered_by_at_path(
                        segments,
                        0,
                        ordered_by,
                        leaves,
                        leaf_lists,
                        containers,
                        lists,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_KEY:
                    self._consume()
                    var key = self._consume_argument_value()
                    self._skip_if(";")
                    if not self._refine_set_key_at_path(
                        segments,
                        0,
                        key,
                        containers,
                        lists,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_UNIQUE:
                    self._consume()
                    var uarg = self._consume_argument_value()
                    var ucomp = self._unique_components_from_argument(uarg)
                    self._skip_if(";")
                    if not self._refine_add_unique_at_path(
                        segments,
                        0,
                        ucomp,
                        containers,
                        lists,
                    ):
                        self._error("Unknown refine target path '" + refine_path + "'")
                elif stmt == YANG_STMT_IF_FEATURE:
                    self._parse_if_feature_statement()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

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
        var parsed = self._parse_augment_statement_body()
        if len(parsed.path) > 0 and String(parsed.path[byte=0 : 1]) == "/":
            self.pending_module_augments.append(Arc[ParsedAugment](parsed^))
            return
        if not self._apply_augment_to_path(
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
            self._error("Unknown augment target path '" + parsed.path + "'")

    def _parse_module_augment_statement(
        mut self,
        mut top_containers: List[Arc[YangContainer]],
    ) raises:
        var parsed = self._parse_augment_statement_body()
        if len(parsed.path) > 0 and String(parsed.path[byte=0 : 1]) == "/":
            self.pending_module_augments.append(Arc[ParsedAugment](parsed^))
            return
        var root_leaves = List[Arc[YangLeaf]]()
        var root_leaf_lists = List[Arc[YangLeafList]]()
        var root_anydatas = List[Arc[YangAnydata]]()
        var root_anyxmls = List[Arc[YangAnyxml]]()
        var root_lists = List[Arc[YangList]]()
        var root_choices = List[Arc[YangChoice]]()
        if not self._apply_augment_to_path(
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
            self._error("Unknown augment target path '" + parsed.path + "'")

    def _apply_pending_module_augments(
        mut self,
        mut top_containers: List[Arc[YangContainer]],
    ) raises:
        var root_leaves = List[Arc[YangLeaf]]()
        var root_leaf_lists = List[Arc[YangLeafList]]()
        var root_anydatas = List[Arc[YangAnydata]]()
        var root_anyxmls = List[Arc[YangAnyxml]]()
        var root_lists = List[Arc[YangList]]()
        var root_choices = List[Arc[YangChoice]]()
        for i in range(len(self.pending_module_augments)):
            var aug_arc = self.pending_module_augments[i].copy()
            ref aug = aug_arc[]
            if not self._apply_augment_to_path(
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
                self._error("Unknown augment target path '" + aug.path + "'")

    def _parse_augment_statement_body(mut self) raises -> ParsedAugment:
        self._expect(YANG_STMT_AUGMENT)
        var target_path = self._consume_argument_value()

        var leaves = List[Arc[YangLeaf]]()
        var leaf_lists = List[Arc[YangLeafList]]()
        var anydatas = List[Arc[YangAnydata]]()
        var anyxmls = List[Arc[YangAnyxml]]()
        var containers = List[Arc[YangContainer]]()
        var lists = List[Arc[YangList]]()
        var choices = List[Arc[YangChoice]]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_LEAF:
                    var leaf = self._parse_leaf_statement()
                    leaves.append(Arc[YangLeaf](leaf^))
                elif stmt == YANG_STMT_LEAF_LIST:
                    var leaf_list = self._parse_leaf_list_statement()
                    leaf_lists.append(Arc[YangLeafList](leaf_list^))
                elif stmt == YANG_STMT_ANYDATA:
                    var ad = self._parse_anydata_statement()
                    anydatas.append(Arc[YangAnydata](ad^))
                elif stmt == YANG_STMT_ANYXML:
                    var ax = self._parse_anyxml_statement()
                    anyxmls.append(Arc[YangAnyxml](ax^))
                elif stmt == YANG_STMT_CONTAINER:
                    var child_container = self._parse_container_statement()
                    containers.append(Arc[YangContainer](child_container^))
                elif stmt == YANG_STMT_LIST:
                    var child_list = self._parse_list_statement()
                    lists.append(Arc[YangList](child_list^))
                elif stmt == YANG_STMT_CHOICE:
                    var choice = self._parse_choice_statement()
                    choices.append(Arc[YangChoice](choice^))
                elif stmt == YANG_STMT_USES:
                    self._parse_uses_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                elif stmt == YANG_STMT_IF_FEATURE:
                    self._parse_if_feature_statement()
                elif stmt == YANG_STMT_AUGMENT:
                    self._parse_relative_augment_statement(
                        leaves,
                        leaf_lists,
                        anydatas,
                        anyxmls,
                        containers,
                        lists,
                        choices,
                    )
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

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
        var segments = self._split_schema_path(path)
        if len(segments) == 0:
            return False
        return self._apply_augment_segments(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(containers)):
                if self._ident_local_name(containers[i][].name) == seg:
                    for j in range(len(aug.leaves)):
                        containers[i][].leaves.append(self._clone_leaf_arc(aug.leaves[j]))
                    for j in range(len(aug.leaf_lists)):
                        containers[i][].leaf_lists.append(
                            self._clone_leaf_list_arc(aug.leaf_lists[j]),
                        )
                    for j in range(len(aug.anydatas)):
                        containers[i][].anydatas.append(self._clone_anydata_arc(aug.anydatas[j]))
                    for j in range(len(aug.anyxmls)):
                        containers[i][].anyxmls.append(self._clone_anyxml_arc(aug.anyxmls[j]))
                    for j in range(len(aug.containers)):
                        containers[i][].containers.append(
                            self._clone_container_arc(aug.containers[j]),
                        )
                    for j in range(len(aug.lists)):
                        containers[i][].lists.append(self._clone_list_arc(aug.lists[j]))
                    for j in range(len(aug.choices)):
                        containers[i][].choices.append(self._clone_choice_arc(aug.choices[j]))
                    applied = True
            for i in range(len(lists)):
                if self._ident_local_name(lists[i][].name) == seg:
                    for j in range(len(aug.leaves)):
                        lists[i][].leaves.append(self._clone_leaf_arc(aug.leaves[j]))
                    for j in range(len(aug.leaf_lists)):
                        lists[i][].leaf_lists.append(self._clone_leaf_list_arc(aug.leaf_lists[j]))
                    for j in range(len(aug.anydatas)):
                        lists[i][].anydatas.append(self._clone_anydata_arc(aug.anydatas[j]))
                    for j in range(len(aug.anyxmls)):
                        lists[i][].anyxmls.append(self._clone_anyxml_arc(aug.anyxmls[j]))
                    for j in range(len(aug.containers)):
                        lists[i][].containers.append(self._clone_container_arc(aug.containers[j]))
                    for j in range(len(aug.lists)):
                        lists[i][].lists.append(self._clone_list_arc(aug.lists[j]))
                    for j in range(len(aug.choices)):
                        lists[i][].choices.append(self._clone_choice_arc(aug.choices[j]))
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._apply_augment_segments(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._apply_augment_segments(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(containers)):
                if self._ident_local_name(containers[i][].name) == seg:
                    containers[i][].description = description
                    applied = True
            for i in range(len(lists)):
                if self._ident_local_name(lists[i][].name) == seg:
                    lists[i][].description = description
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_description_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_description_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaves)):
                if self._ident_local_name(leaves[i][].name) == seg:
                    leaves[i][].mandatory = mandatory
                    applied = True
            for i in range(len(choices)):
                if self._ident_local_name(choices[i][].name) == seg:
                    choices[i][].mandatory = mandatory
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_mandatory_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_mandatory_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaves)):
                if self._ident_local_name(leaves[i][].name) == seg:
                    leaves[i][].default_value = default_value
                    leaves[i][].has_default = True
                    applied = True
            for i in range(len(leaf_lists)):
                if self._ident_local_name(leaf_lists[i][].name) == seg:
                    leaf_lists[i][].default_values.append(default_value)
                    applied = True
            for i in range(len(choices)):
                if self._ident_local_name(choices[i][].name) == seg:
                    choices[i][].default_case = default_value
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_default_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_default_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaves)):
                if self._ident_local_name(leaves[i][].name) == seg:
                    leaves[i][].must_statements.append(Arc[YangMust](self._clone_must(must_stmt)))
                    applied = True
            for i in range(len(leaf_lists)):
                if self._ident_local_name(leaf_lists[i][].name) == seg:
                    leaf_lists[i][].must_statements.append(
                        Arc[YangMust](self._clone_must(must_stmt)),
                    )
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_add_must_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_add_must_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaves)):
                if self._ident_local_name(leaves[i][].name) == seg:
                    leaves[i][].when = Optional(self._clone_when(when_stmt))
                    applied = True
            for i in range(len(leaf_lists)):
                if self._ident_local_name(leaf_lists[i][].name) == seg:
                    leaf_lists[i][].when = Optional(self._clone_when(when_stmt))
                    applied = True
            for i in range(len(choices)):
                if self._ident_local_name(choices[i][].name) == seg:
                    choices[i][].when = Optional(self._clone_when(when_stmt))
                    applied = True
                for j in range(len(choices[i][].cases)):
                    if self._ident_local_name(choices[i][].cases[j][].name) == seg:
                        choices[i][].cases[j][].when = Optional(self._clone_when(when_stmt))
                        applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_when_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_when_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaves)):
                if self._ident_local_name(leaves[i][].name) == seg:
                    leaves[i][].type = self._clone_yang_type(type_stmt)
                    applied = True
            for i in range(len(leaf_lists)):
                if self._ident_local_name(leaf_lists[i][].name) == seg:
                    leaf_lists[i][].type = self._clone_yang_type(type_stmt)
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_type_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_type_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaf_lists)):
                if self._ident_local_name(leaf_lists[i][].name) == seg:
                    leaf_lists[i][].min_elements = value
                    applied = True
            for i in range(len(lists)):
                if self._ident_local_name(lists[i][].name) == seg:
                    lists[i][].min_elements = value
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_min_elements_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_min_elements_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaf_lists)):
                if self._ident_local_name(leaf_lists[i][].name) == seg:
                    leaf_lists[i][].max_elements = value
                    applied = True
            for i in range(len(lists)):
                if self._ident_local_name(lists[i][].name) == seg:
                    lists[i][].max_elements = value
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_max_elements_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_max_elements_at_path(
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
        var seg = segments[seg_idx]
        if seg_idx == len(segments) - 1:
            var applied = False
            for i in range(len(leaf_lists)):
                if self._ident_local_name(leaf_lists[i][].name) == seg:
                    leaf_lists[i][].ordered_by = value
                    applied = True
            for i in range(len(lists)):
                if self._ident_local_name(lists[i][].name) == seg:
                    lists[i][].ordered_by = value
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_ordered_by_at_path(
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
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_ordered_by_at_path(
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

    def _refine_set_key_at_path(
        ref self,
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
                if self._ident_local_name(lists[i][].name) == seg:
                    lists[i][].key = key
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_set_key_at_path(
                    segments,
                    seg_idx + 1,
                    key,
                    containers[i][].containers,
                    containers[i][].lists,
                ):
                    applied = True
        for i in range(len(lists)):
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_set_key_at_path(
                    segments,
                    seg_idx + 1,
                    key,
                    lists[i][].containers,
                    lists[i][].lists,
                ):
                    applied = True
        return applied

    def _refine_add_unique_at_path(
        ref self,
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
                if self._ident_local_name(lists[i][].name) == seg:
                    lists[i][].unique_specs.append(unique_spec.copy())
                    applied = True
            return applied

        var applied = False
        for i in range(len(containers)):
            if self._ident_local_name(containers[i][].name) == seg:
                if self._refine_add_unique_at_path(
                    segments,
                    seg_idx + 1,
                    unique_spec,
                    containers[i][].containers,
                    containers[i][].lists,
                ):
                    applied = True
        for i in range(len(lists)):
            if self._ident_local_name(lists[i][].name) == seg:
                if self._refine_add_unique_at_path(
                    segments,
                    seg_idx + 1,
                    unique_spec,
                    lists[i][].containers,
                    lists[i][].lists,
                ):
                    applied = True
        return applied

    def _split_schema_path(ref self, path: String) -> List[String]:
        var out = List[String]()
        var trimmed = path.strip()
        var parts = trimmed.split("/")
        for i in range(len(parts)):
            var raw = String(String(parts[i]).strip())
            if len(raw) == 0 or raw == ".":
                continue
            out.append(self._ident_local_name(raw))
        return out^

    def _ident_local_name(ref self, ident: String) -> String:
        var parts = ident.split(":")
        if len(parts) == 0:
            return ident
        return String(String(parts[len(parts) - 1]).strip())

    def _clone_must(ref self, read src: YangMust) -> YangMust:
        var xpath_ast = Expr.ExprPointer()
        try:
            xpath_ast = parse_xpath(src.expression)
            return YangMust(
                expression = src.expression,
                error_message = src.error_message,
                description = src.description,
                xpath_ast = xpath_ast,
                parsed = True,
            )
        except:
            return YangMust(
                expression = src.expression,
                error_message = src.error_message,
                description = src.description,
                xpath_ast = xpath_ast,
                parsed = False,
            )

    def _clone_when(ref self, read src: YangWhen) -> YangWhen:
        var xpath_ast = Expr.ExprPointer()
        try:
            xpath_ast = parse_xpath(src.expression)
            return YangWhen(
                expression = src.expression,
                description = src.description,
                xpath_ast = xpath_ast,
                parsed = True,
            )
        except:
            return YangWhen(
                expression = src.expression,
                description = src.description,
                xpath_ast = xpath_ast,
                parsed = False,
            )

    def _clone_yang_type(ref self, read src: YangType) -> YangType:
        var union_members = List[Arc[YangType]]()
        for i in range(src.union_members_len()):
            union_members.append(Arc[YangType](self._clone_yang_type(src.union_member_arc(i)[])))

        if src.name == "enumeration":
            var enum_values = List[String]()
            for i in range(src.enum_values_len()):
                enum_values.append(src.enum_value_at(i))
            return YangType(
                name = src.name,
                constraints = YangTypeEnumeration(enum_values^),
                union_members = union_members^,
            )

        if src.name == "decimal64":
            return YangType(
                name = src.name,
                constraints = YangTypeDecimal64(
                    src.fraction_digits(),
                    src.has_decimal64_range(),
                    src.decimal64_range_min(),
                    src.decimal64_range_max(),
                ),
                union_members = union_members^,
            )

        if src.name == YANG_TYPE_LEAFREF:
            var xpath_ast = Expr.ExprPointer()
            var parsed = False
            if src.has_leafref_path():
                try:
                    xpath_ast = parse_xpath(src.leafref_path())
                    parsed = True
                except:
                    parsed = False
            return YangType(
                name = src.name,
                constraints = YangTypeLeafref(
                    src.has_leafref_path(),
                    src.leafref_path(),
                    src.leafref_require_instance(),
                    xpath_ast,
                    parsed,
                ),
                union_members = union_members^,
            )

        if src.name == "bits":
            var names = List[String]()
            for i in range(src.bits_names_len()):
                names.append(src.bits_name_at(i))
            return YangType(
                name = src.name,
                constraints = YangTypeBits(names^),
                union_members = union_members^,
            )

        if src.name == "identityref":
            return YangType(
                name = src.name,
                constraints = YangTypeIdentityref(src.identityref_base()),
                union_members = union_members^,
            )

        if src.name == "union":
            return YangType(
                name = src.name,
                constraints = YangTypePlain(_pad=0),
                union_members = union_members^,
            )

        if (
            src.name == "integer"
            or src.name == "int8"
            or src.name == "int16"
            or src.name == "int32"
            or src.name == "int64"
            or src.name == "uint8"
            or src.name == "uint16"
            or src.name == "uint32"
            or src.name == "uint64"
            or src.name == "number"
        ):
            return YangType(
                name = src.name,
                constraints = YangTypeIntegerRange(
                    src.has_range(),
                    src.range_min(),
                    src.range_max(),
                ),
                union_members = union_members^,
            )

        return YangType(
            name = src.name,
            constraints = YangTypePlain(_pad=0),
            union_members = union_members^,
        )

    def _clone_leaf_arc(ref self, read src: Arc[YangLeaf]) -> Arc[YangLeaf]:
        var musts = List[Arc[YangMust]]()
        for i in range(len(src[].must_statements)):
            musts.append(Arc[YangMust](self._clone_must(src[].must_statements[i][])))

        var when = Optional[YangWhen]()
        if Bool(src[].when):
            when = Optional(self._clone_when(src[].when.value()))

        return Arc[YangLeaf](
            YangLeaf(
                name = src[].name,
                type = self._clone_yang_type(src[].type),
                mandatory = src[].mandatory,
                has_default = src[].has_default,
                default_value = src[].default_value,
                must_statements = musts^,
                when = when^,
            ),
        )

    def _clone_leaf_list_arc(ref self, read src: Arc[YangLeafList]) -> Arc[YangLeafList]:
        var musts = List[Arc[YangMust]]()
        for i in range(len(src[].must_statements)):
            musts.append(Arc[YangMust](self._clone_must(src[].must_statements[i][])))

        var when = Optional[YangWhen]()
        if Bool(src[].when):
            when = Optional(self._clone_when(src[].when.value()))

        return Arc[YangLeafList](
            YangLeafList(
                name = src[].name,
                type = self._clone_yang_type(src[].type),
                default_values = src[].default_values.copy(),
                must_statements = musts^,
                when = when^,
                min_elements = src[].min_elements,
                max_elements = src[].max_elements,
                ordered_by = src[].ordered_by,
            ),
        )

    def _clone_choice_arc(ref self, read src: Arc[YangChoice]) -> Arc[YangChoice]:
        var cases = List[Arc[YangChoiceCase]]()
        for i in range(len(src[].cases)):
            var case_when = Optional[YangWhen]()
            if Bool(src[].cases[i][].when):
                case_when = Optional(self._clone_when(src[].cases[i][].when.value()))
            cases.append(Arc[YangChoiceCase](
                YangChoiceCase(
                    name = src[].cases[i][].name,
                    node_names = src[].cases[i][].node_names.copy(),
                    when = case_when^,
                ),
            ))

        var choice_when = Optional[YangWhen]()
        if Bool(src[].when):
            choice_when = Optional(self._clone_when(src[].when.value()))

        return Arc[YangChoice](
            YangChoice(
                name = src[].name,
                mandatory = src[].mandatory,
                default_case = src[].default_case,
                case_names = src[].case_names.copy(),
                cases = cases^,
                when = choice_when^,
            ),
        )

    def _clone_anydata_arc(ref self, read src: Arc[YangAnydata]) -> Arc[YangAnydata]:
        var musts = List[Arc[YangMust]]()
        for i in range(len(src[].must_statements)):
            musts.append(Arc[YangMust](self._clone_must(src[].must_statements[i][])))
        var when = Optional[YangWhen]()
        if src[].has_when():
            when = Optional(self._clone_when(src[].when.value()))
        return Arc[YangAnydata](
            YangAnydata(
                name = src[].name,
                description = src[].description,
                mandatory = src[].mandatory,
                must_statements = musts^,
                when = when^,
            ),
        )

    def _clone_anyxml_arc(ref self, read src: Arc[YangAnyxml]) -> Arc[YangAnyxml]:
        var musts = List[Arc[YangMust]]()
        for i in range(len(src[].must_statements)):
            musts.append(Arc[YangMust](self._clone_must(src[].must_statements[i][])))
        var when = Optional[YangWhen]()
        if src[].has_when():
            when = Optional(self._clone_when(src[].when.value()))
        return Arc[YangAnyxml](
            YangAnyxml(
                name = src[].name,
                description = src[].description,
                mandatory = src[].mandatory,
                must_statements = musts^,
                when = when^,
            ),
        )

    def _clone_container_arc(ref self, read src: Arc[YangContainer]) -> Arc[YangContainer]:
        var leaves = List[Arc[YangLeaf]]()
        var leaf_lists = List[Arc[YangLeafList]]()
        var anydatas = List[Arc[YangAnydata]]()
        var anyxmls = List[Arc[YangAnyxml]]()
        var containers = List[Arc[YangContainer]]()
        var lists = List[Arc[YangList]]()
        var choices = List[Arc[YangChoice]]()

        for i in range(len(src[].leaves)):
            leaves.append(self._clone_leaf_arc(src[].leaves[i]))
        for i in range(len(src[].leaf_lists)):
            leaf_lists.append(self._clone_leaf_list_arc(src[].leaf_lists[i]))
        for i in range(len(src[].anydatas)):
            anydatas.append(self._clone_anydata_arc(src[].anydatas[i]))
        for i in range(len(src[].anyxmls)):
            anyxmls.append(self._clone_anyxml_arc(src[].anyxmls[i]))
        for i in range(len(src[].containers)):
            containers.append(self._clone_container_arc(src[].containers[i]))
        for i in range(len(src[].lists)):
            lists.append(self._clone_list_arc(src[].lists[i]))
        for i in range(len(src[].choices)):
            choices.append(self._clone_choice_arc(src[].choices[i]))

        return Arc[YangContainer](
            YangContainer(
                name = src[].name,
                description = src[].description,
                leaves = leaves^,
                leaf_lists = leaf_lists^,
                anydatas = anydatas^,
                anyxmls = anyxmls^,
                containers = containers^,
                lists = lists^,
                choices = choices^,
            ),
        )

    def _clone_list_arc(ref self, read src: Arc[YangList]) -> Arc[YangList]:
        var leaves = List[Arc[YangLeaf]]()
        var leaf_lists = List[Arc[YangLeafList]]()
        var anydatas = List[Arc[YangAnydata]]()
        var anyxmls = List[Arc[YangAnyxml]]()
        var containers = List[Arc[YangContainer]]()
        var lists = List[Arc[YangList]]()
        var choices = List[Arc[YangChoice]]()
        var unique_specs = List[List[String]]()

        for i in range(len(src[].leaves)):
            leaves.append(self._clone_leaf_arc(src[].leaves[i]))
        for i in range(len(src[].leaf_lists)):
            leaf_lists.append(self._clone_leaf_list_arc(src[].leaf_lists[i]))
        for i in range(len(src[].anydatas)):
            anydatas.append(self._clone_anydata_arc(src[].anydatas[i]))
        for i in range(len(src[].anyxmls)):
            anyxmls.append(self._clone_anyxml_arc(src[].anyxmls[i]))
        for i in range(len(src[].containers)):
            containers.append(self._clone_container_arc(src[].containers[i]))
        for i in range(len(src[].lists)):
            lists.append(self._clone_list_arc(src[].lists[i]))
        for i in range(len(src[].choices)):
            choices.append(self._clone_choice_arc(src[].choices[i]))
        for i in range(len(src[].unique_specs)):
            unique_specs.append(src[].unique_specs[i].copy())

        return Arc[YangList](
            YangList(
                name = src[].name,
                key = src[].key,
                description = src[].description,
                leaves = leaves^,
                leaf_lists = leaf_lists^,
                anydatas = anydatas^,
                anyxmls = anyxmls^,
                containers = containers^,
                lists = lists^,
                choices = choices^,
                min_elements = src[].min_elements,
                max_elements = src[].max_elements,
                ordered_by = src[].ordered_by,
                unique_specs = unique_specs^,
            ),
        )

    def _parse_type_statement(mut self) raises -> YangType:
        self._expect(YANG_STMT_TYPE)
        var type_name = self._consume_name()
        var has_range = False
        var range_min = Int64(0)
        var range_max = Int64(0)
        var enum_values = List[String]()
        var union_types = List[Arc[YangType]]()
        var has_leafref_path = False
        var leafref_path = ""
        var leafref_require_instance = True
        var leafref_xpath_ast = Expr.ExprPointer()
        var leafref_path_parsed = False
        var fraction_digits = 0
        var has_dec_range = False
        var dec_lo = Float64(0.0)
        var dec_hi = Float64(0.0)
        var bits_names = List[String]()
        var identityref_base = ""

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_RANGE:
                    self._consume()
                    var range_expr = self._consume_argument_value()
                    var parts = range_expr.split("..")
                    if len(parts) == 2 and type_name == "decimal64":
                        try:
                            var a = parts[0].strip()
                            var b = parts[1].strip()
                            dec_lo = atof(a)
                            dec_hi = atof(b)
                            has_dec_range = True
                        except:
                            has_dec_range = False
                    elif len(parts) == 2:
                        try:
                            range_min = Int64(atol(parts[0].strip()))
                            range_max = Int64(atol(parts[1].strip()))
                            has_range = True
                        except:
                            has_range = False
                    self._skip_if(";")
                elif stmt == YANG_STMT_PATH:
                    self._consume()
                    leafref_path = self._consume_argument_value()
                    has_leafref_path = True
                    try:
                        leafref_xpath_ast = parse_xpath(leafref_path)
                        leafref_path_parsed = True
                    except:
                        leafref_xpath_ast = Expr.ExprPointer()
                        leafref_path_parsed = False
                    self._skip_if(";")
                elif stmt == YANG_STMT_REQUIRE_INSTANCE:
                    self._consume()
                    leafref_require_instance = self._parse_boolean_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_ENUM:
                    self._consume()
                    enum_values.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_TYPE and type_name == YANG_STMT_UNION:
                    var union_type = self._parse_type_statement()
                    union_types.append(Arc[YangType](union_type^))
                elif stmt == YANG_STMT_FRACTION_DIGITS and type_name == "decimal64":
                    self._consume()
                    try:
                        var fd = atol(self._consume_name().strip())
                        if fd >= 1 and fd <= 18:
                            fraction_digits = Int(fd)
                    except:
                        pass
                    self._skip_if(";")
                elif stmt == YANG_STMT_BIT and type_name == "bits":
                    self._consume()
                    bits_names.append(self._consume_name())
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_BASE and type_name == "identityref":
                    self._consume()
                    identityref_base = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        if type_name == YANG_TYPE_ENUMERATION and len(enum_values) == 0:
            self._error(
                "enumeration type requires at least one '" + YANG_STMT_ENUM + "' statement",
            )
            return YangType(
                name = type_name,
                constraints = _yang_constraints_for_parsed_type(
                    type_name,
                    has_range,
                    range_min,
                    range_max,
                    enum_values^,
                    has_leafref_path,
                    leafref_path,
                    leafref_require_instance,
                    leafref_xpath_ast,
                    leafref_path_parsed,
                    fraction_digits,
                    has_dec_range,
                    dec_lo,
                    dec_hi,
                    bits_names^,
                    identityref_base,
                ),
                union_members = union_types^,
            )

        if type_name == YANG_STMT_UNION:
            return YangType(
                name = type_name,
                constraints = YangTypePlain(_pad=0),
                union_members = union_types^,
            )

        return YangType(
            name = type_name,
            constraints = _yang_constraints_for_parsed_type(
                type_name,
                has_range,
                range_min,
                range_max,
                enum_values^,
                has_leafref_path,
                leafref_path,
                leafref_require_instance,
                leafref_xpath_ast,
                leafref_path_parsed,
                fraction_digits,
                has_dec_range,
                dec_lo,
                dec_hi,
                bits_names^,
                identityref_base,
            ),
            union_members = List[Arc[YangType]](),
        )

    def _parse_must_statement(mut self) raises -> YangMust:
        self._expect(YANG_STMT_MUST)
        var expression = self._consume_argument_value()
        var error_message = ""
        var description = ""

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_ERROR_MESSAGE:
                    self._consume()
                    error_message = self._consume_argument_value()
                    self._skip_if(";")
                elif stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    description = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        var xpath_ast = Expr.ExprPointer()
        try:
            xpath_ast = parse_xpath(expression)
            return YangMust(
                expression = expression,
                error_message = error_message,
                description = description,
                xpath_ast = xpath_ast,
                parsed = True,
            )
        except:
            return YangMust(
                expression = expression,
                error_message = error_message,
                description = description,
                xpath_ast = xpath_ast,
                parsed = False,
            )

    def _parse_when_statement(mut self) raises -> YangWhen:
        self._expect(YANG_STMT_WHEN)
        var expression = self._consume_argument_value()
        var description = ""

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_DESCRIPTION:
                    self._consume()
                    description = self._consume_argument_value()
                    self._skip_if(";")
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        var xpath_ast = Expr.ExprPointer()
        try:
            xpath_ast = parse_xpath(expression)
            return YangWhen(
                expression = expression,
                description = description,
                xpath_ast = xpath_ast,
                parsed = True,
            )
        except:
            return YangWhen(
                expression = expression,
                description = description,
                xpath_ast = xpath_ast,
                parsed = False,
            )

    def _parse_non_negative_int(mut self, label: String) raises -> Int:
        var raw = self._consume_argument_value().strip()
        try:
            var n = atol(raw)
            if n < 0:
                self._error(label + " must be non-negative, got '" + raw + "'")
            return Int(n)
        except:
            self._error("Invalid integer for " + label + ": '" + raw + "'")
            return 0

    def _parse_ordered_by_argument(mut self) raises -> String:
        var v = self._consume_argument_value()
        if v != "user" and v != "system":
            self._error("ordered-by must be 'user' or 'system', got '" + v + "'")
        return v

    def _unique_components_from_argument(mut self, arg: String) raises -> List[String]:
        var parts = arg.strip().split()
        var out = List[String]()
        for i in range(len(parts)):
            var seg = String(String(parts[i]).strip())
            if len(seg) > 0:
                out.append(seg^)
        return out^

    def _validate_choice_unique_node_names(mut self, read choice: YangChoice) raises:
        var seen = Dict[String, String]()
        for i in range(len(choice.cases)):
            ref c = choice.cases[i][]
            for j in range(len(c.node_names)):
                var nm = c.node_names[j]
                if nm in seen:
                    self._error(
                        "Choice '"
                        + choice.name
                        + "': node '"
                        + nm
                        + "' appears in case '"
                        + seen[nm]
                        + "' and case '"
                        + c.name
                        + "' (RFC 7950 §7.9)",
                    )
                seen[nm] = c.name

    def _parse_boolean_value(mut self) raises -> Bool:
        var value = self._consume_value()
        if value == YANG_BOOL_TRUE:
            return True
        if value == YANG_BOOL_FALSE:
            return False
        self._error("Expected boolean value 'true' or 'false', got '" + value + "'")
        return False

    def _consume_argument_value(mut self) raises -> String:
        if not self._has_more():
            self._error("Expected argument value, found end of input")
            return ""

        var value = self._consume_value()

        # YANG string concatenation: "a" + "b"
        while self._consume_if("+"):
            value += self._consume_value()

        return value

    def _consume_name(mut self) raises -> String:
        var first = self._consume_value()
        if first == "{" or first == "}" or first == ";":
            self._error("Expected statement argument, got '" + first + "'")
            return ""

        var name = first
        while self._consume_if(":"):
            name += ":"
            name += self._consume_value()
        return name

    def _skip_statement_tail(mut self) raises:
        if self._consume_if(";"):
            return
        if self._consume_if("{"):
            self._skip_block_body()
            self._skip_if(";")
            return
        while self._has_more():
            var v = self._peek()
            if v == ";":
                self._consume()
                return
            if v == "{":
                self._consume()
                self._skip_block_body()
                self._skip_if(";")
                return
            if v == "}":
                return
            self._consume()

    def _skip_statement(mut self) raises:
        self._consume()
        self._skip_statement_tail()

    def _skip_block_body(mut self) raises:
        # Entry point assumes the opening '{' was already consumed.
        var depth = 1
        while self._has_more() and depth > 0:
            var value = self._consume_value()
            if value == "{":
                depth += 1
            elif value == "}":
                depth -= 1

    def _expect(mut self, value: String) raises:
        if not self._has_more():
            self._error("Expected '" + value + "', found end of input")
            return
        var got = self._peek()
        if got != value:
            self._error("Expected '" + value + "', got '" + got + "'")
            return
        self.index += 1

    def _consume_if(mut self, value: String) -> Bool:
        if self._has_more() and self.tokens[self.index].value == value:
            self.index += 1
            return True
        return False

    def _skip_if(mut self, value: String):
        if self._has_more() and self.tokens[self.index].value == value:
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
        var tok_value = self.tokens[self.index].value.copy()
        self.index += 1
        return tok_value

    def _peek(ref self) -> String:
        return self.tokens[self.index].value

    def _has_more(ref self) -> Bool:
        return self.index < len(self.tokens)

    def _error(ref self, message: String) raises:
        if self._has_more():
            ref tok = self.tokens[self.index]
            raise Error(
                "YANG parse error at line "
                + String(tok.line)
                + ", col "
                + String(tok.col)
                + ": "
                + message,
            )
        raise Error("YANG parse error at end of input: " + message)


def tokenize_yang(source: String) -> List[YangToken]:
    var tokens = List[YangToken]()

    var i = 0
    var n = len(source)
    var line = 1
    var line_start = 0

    while i < n:
        var ch = _codepoint_at_byte(source, i)

        if _is_space(ch):
            if ch == CP_NEWLINE:
                line += 1
                line_start = i + 1
            i += 1
            continue

        if ch == CP_SLASH and i + 1 < n:
            var nxt = _codepoint_at_byte(source, i + 1)
            if nxt == CP_SLASH:
                i += 2
                while i < n and _codepoint_at_byte(source, i) != CP_NEWLINE:
                    i += 1
                continue
            if nxt == CP_STAR:
                i += 2
                while i < n:
                    var c = _codepoint_at_byte(source, i)
                    if i + 1 < n and c == CP_STAR and _codepoint_at_byte(source, i + 1) == CP_SLASH:
                        i += 2
                        break
                    if c == CP_NEWLINE:
                        line += 1
                        line_start = i + 1
                    i += 1
                continue

        if _is_symbol(ch):
            tokens.append(
                YangToken(
                    value=String(source[byte=i : i + 1]),
                    quoted=False,
                    line=line,
                    col=i - line_start,
                ),
            )
            i += 1
            continue

        if ch == CP_DQUOTE or ch == CP_SQUOTE:
            var quote = ch
            var start_col = i - line_start
            i += 1
            var out = ""
            while i < n:
                var c = _codepoint_at_byte(source, i)
                if c == quote:
                    i += 1
                    break
                if c == CP_BACKSLASH and i + 1 < n:
                    out += String(source[byte=i + 1 : i + 2])
                    i += 2
                    continue
                out += String(source[byte=i : i + 1])
                if c == CP_NEWLINE:
                    line += 1
                    line_start = i + 1
                i += 1
            tokens.append(YangToken(value=out, quoted=True, line=line, col=start_col))
            continue

        var start = i
        var col = i - line_start
        while i < n:
            var c = _codepoint_at_byte(source, i)
            if _is_space(c) or _is_symbol(c) or c == CP_DQUOTE or c == CP_SQUOTE:
                break
            if c == CP_SLASH and i + 1 < n:
                var n2 = _codepoint_at_byte(source, i + 1)
                if n2 == CP_SLASH or n2 == CP_STAR:
                    break
            i += 1
        if i > start:
            tokens.append(
                YangToken(
                    value=String(source[byte=start : i]),
                    quoted=False,
                    line=line,
                    col=col,
                ),
            )
            continue

        i += 1

    return tokens^


def _is_space(ch: Codepoint) -> Bool:
    return ch.is_posix_space()


def _is_symbol(ch: Codepoint) -> Bool:
    return (
        ch == CP_BRACE_OPEN
        or ch == CP_BRACE_CLOSE
        or ch == CP_SEMICOLON
        or ch == CP_COLON
        or ch == CP_PLUS
    )


def _codepoint_at_byte(source: String, i: Int) -> Codepoint:
    return Codepoint.ord(source[byte=i : i + 1])


def parse_yang_string(source: String) raises -> YangModule:
    var tokens = tokenize_yang(source)
    var parser = _YangParser(tokens^)
    return parser.parse_module()


def parse_yang_file(path: String) raises -> YangModule:
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return parse_yang_string(text)
