## Text YANG parser for Mojo AST (modeled after Python xYang parser flow).
##
## Supported subset:
## - module header: module, namespace, prefix, description, revision (list, body skipped)
## - data nodes: container, list, leaf, choice/case
## - leaf/list details: type, mandatory, key
## - must on leaves with optional error-message/description block

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
    YangType,
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
    YANG_STMT_GROUPING,
    YANG_STMT_KEY,
    YANG_STMT_LEAF,
    YANG_STMT_LEAF_LIST,
    YANG_STMT_LIST,
    YANG_STMT_MANDATORY,
    YANG_STMT_MODULE,
    YANG_STMT_MUST,
    YANG_STMT_NAMESPACE,
    YANG_STMT_ORGANIZATION,
    YANG_STMT_PATH,
    YANG_STMT_PREFIX,
    YANG_STMT_RANGE,
    YANG_STMT_REQUIRE_INSTANCE,
    YANG_STMT_REVISION,
    YANG_STMT_TYPE,
    YANG_STMT_UNION,
    YANG_STMT_USES,
    YANG_STMT_WHEN,
    YANG_TYPE_ENUMERATION,
    YANG_TYPE_UNKNOWN,
)

comptime Arc = ArcPointer
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
struct ParsedChoiceCase(Movable):
    var name: String
    var node_names: List[String]


@fieldwise_init
struct ParsedGrouping(Movable):
    var name: String
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]


struct _YangParser(Movable):
    var tokens: List[YangToken]
    var index: Int
    var grouping_names: List[String]
    var groupings: List[Arc[ParsedGrouping]]

    def __init__(out self, var tokens: List[YangToken]):
        self.tokens = tokens^
        self.index = 0
        self.grouping_names = List[String]()
        self.groupings = List[Arc[ParsedGrouping]]()

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
            else:
                self._skip_statement()

        self._expect("}")
        self._skip_if(";")

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
                        containers,
                        lists,
                        choices,
                    )
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangContainer(
            name = name,
            description = desc,
            leaves = leaves^,
            leaf_lists = leaf_lists^,
            containers = containers^,
            lists = lists^,
            choices = choices^,
        )

    def _parse_list_statement(mut self) raises -> YangList:
        self._expect(YANG_STMT_LIST)
        var name = self._consume_name()

        var key = ""
        var desc = ""
        var leaves = List[Arc[YangLeaf]]()
        var leaf_lists = List[Arc[YangLeafList]]()
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
                        containers,
                        lists,
                        choices,
                    )
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
            containers = containers^,
            lists = lists^,
            choices = choices^,
        )

    def _parse_leaf_statement(mut self) raises -> YangLeaf:
        self._expect(YANG_STMT_LEAF)
        var name = self._consume_name()

        var type_stmt = YangType(
            name = YANG_TYPE_UNKNOWN,
            has_range = False,
            range_min = 0,
            range_max = 0,
            enum_values = List[String](),
            union_types = List[Arc[YangType]](),
            has_leafref_path = False,
            leafref_path = "",
            leafref_require_instance = True,
            leafref_xpath_ast = Expr.ExprPointer(),
            leafref_path_parsed = False,
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
                    default_value = self._consume_argument_value()
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
            has_range = False,
            range_min = 0,
            range_max = 0,
            enum_values = List[String](),
            union_types = List[Arc[YangType]](),
            has_leafref_path = False,
            leafref_path = "",
            leafref_require_instance = True,
            leafref_xpath_ast = Expr.ExprPointer(),
            leafref_path_parsed = False,
        )
        var must = List[Arc[YangMust]]()
        var when = Optional[YangWhen]()
        var default_values = List[String]()

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_TYPE:
                    type_stmt = self._parse_type_statement()
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
        )

    def _parse_choice_statement(mut self) raises -> YangChoice:
        self._expect(YANG_STMT_CHOICE)
        var name = self._consume_name()

        var mandatory = False
        var default_case = ""
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
                elif stmt == YANG_STMT_CASE:
                    var parsed_case = self._parse_case_statement()
                    for i in range(len(parsed_case.node_names)):
                        case_names.append(parsed_case.node_names[i])
                    cases.append(Arc[YangChoiceCase](
                        YangChoiceCase(
                            name=parsed_case.name,
                            node_names=parsed_case.node_names.copy(),
                        ),
                    ))
                elif stmt == YANG_STMT_LEAF:
                    self._consume()
                    var node_name = self._consume_name()
                    case_names.append(node_name)
                    var implicit_names = List[String]()
                    implicit_names.append(node_name)
                    cases.append(Arc[YangChoiceCase](
                        YangChoiceCase(name=node_name, node_names=implicit_names^),
                    ))
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_CONTAINER:
                    self._consume()
                    var node_name = self._consume_name()
                    case_names.append(node_name)
                    var implicit_names = List[String]()
                    implicit_names.append(node_name)
                    cases.append(Arc[YangChoiceCase](
                        YangChoiceCase(name=node_name, node_names=implicit_names^),
                    ))
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_LIST:
                    self._consume()
                    var node_name = self._consume_name()
                    case_names.append(node_name)
                    var implicit_names = List[String]()
                    implicit_names.append(node_name)
                    cases.append(Arc[YangChoiceCase](
                        YangChoiceCase(name=node_name, node_names=implicit_names^),
                    ))
                    self._skip_statement_tail()
                elif stmt == YANG_STMT_LEAF_LIST:
                    self._consume()
                    var node_name = self._consume_name()
                    case_names.append(node_name)
                    var implicit_names = List[String]()
                    implicit_names.append(node_name)
                    cases.append(Arc[YangChoiceCase](
                        YangChoiceCase(name=node_name, node_names=implicit_names^),
                    ))
                    self._skip_statement_tail()
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return YangChoice(
            name = name,
            mandatory = mandatory,
            default_case = default_case,
            case_names = case_names^,
            cases = cases^,
        )

    def _parse_case_statement(mut self) raises -> ParsedChoiceCase:
        self._expect(YANG_STMT_CASE)
        var case_name = self._consume_name()

        var names = List[String]()

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
                else:
                    self._skip_statement()
            self._expect("}")
        self._skip_if(";")

        return ParsedChoiceCase(name=case_name, node_names=names^)

    def _parse_grouping_statement(mut self) raises:
        self._expect(YANG_STMT_GROUPING)
        var name = self._consume_name()

        var leaves = List[Arc[YangLeaf]]()
        var leaf_lists = List[Arc[YangLeafList]]()
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
                name = name,
                leaves = leaves^,
                leaf_lists = leaf_lists^,
                containers = containers^,
                lists = lists^,
                choices = choices^,
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
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) raises:
        self._expect(YANG_STMT_USES)
        var grouping_name = self._consume_name()
        self._skip_statement_tail()
        self._append_grouping_nodes_by_name(
            grouping_name,
            leaves,
            leaf_lists,
            containers,
            lists,
            choices,
        )

    def _append_grouping_nodes_by_name(
        mut self,
        grouping_name: String,
        mut leaves: List[Arc[YangLeaf]],
        mut leaf_lists: List[Arc[YangLeafList]],
        mut containers: List[Arc[YangContainer]],
        mut lists: List[Arc[YangList]],
        mut choices: List[Arc[YangChoice]],
    ) raises:
        var idx = self._find_grouping_index(grouping_name)
        if idx < 0:
            self._error("Unknown grouping '" + grouping_name + "' in uses statement")
            return
        for i in range(len(self.groupings[idx][].leaves)):
            leaves.append(self.groupings[idx][].leaves[i].copy())
        for i in range(len(self.groupings[idx][].leaf_lists)):
            leaf_lists.append(self.groupings[idx][].leaf_lists[i].copy())
        for i in range(len(self.groupings[idx][].containers)):
            containers.append(self.groupings[idx][].containers[i].copy())
        for i in range(len(self.groupings[idx][].lists)):
            lists.append(self.groupings[idx][].lists[i].copy())
        for i in range(len(self.groupings[idx][].choices)):
            choices.append(self.groupings[idx][].choices[i].copy())

    def _find_grouping_index(ref self, grouping_name: String) -> Int:
        for i in range(len(self.grouping_names)):
            if self.grouping_names[i] == grouping_name:
                return i
        return -1

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

        if self._consume_if("{"):
            while self._has_more() and self._peek() != "}":
                var stmt = self._peek()
                if stmt == YANG_STMT_RANGE:
                    self._consume()
                    var range_expr = self._consume_argument_value()
                    var parts = range_expr.split("..")
                    if len(parts) == 2:
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
                has_range = has_range,
                range_min = range_min,
                range_max = range_max,
                enum_values = enum_values^,
                union_types = union_types^,
                has_leafref_path = has_leafref_path,
                leafref_path = leafref_path,
                leafref_require_instance = leafref_require_instance,
                leafref_xpath_ast = leafref_xpath_ast,
                leafref_path_parsed = leafref_path_parsed,
            )

        return YangType(
            name = type_name,
            has_range = has_range,
            range_min = range_min,
            range_max = range_max,
            enum_values = enum_values^,
            union_types = union_types^,
            has_leafref_path = has_leafref_path,
            leafref_path = leafref_path,
            leafref_require_instance = leafref_require_instance,
            leafref_xpath_ast = leafref_xpath_ast,
            leafref_path_parsed = leafref_path_parsed,
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
