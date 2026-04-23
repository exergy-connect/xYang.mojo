## Minimal YANG AST model in Mojo for xYang.mojo.

from std.memory import ArcPointer
from emberjson import JsonDeserializable
from xyang.xpath import Expr

comptime Arc = ArcPointer


@fieldwise_init
struct YangType(Movable, JsonDeserializable):
    var name: String
    var has_range: Bool
    var range_min: Int64
    var range_max: Int64
    var enum_values: List[String]
    var union_types: List[Arc[YangType]]
    var has_leafref_path: Bool
    var leafref_path: String
    var leafref_require_instance: Bool
    var leafref_xpath_ast: Expr.ExprPointer
    var leafref_path_parsed: Bool

    fn __del__(deinit self):
        if self.leafref_xpath_ast:
            self.leafref_xpath_ast[].free_tree()
            self.leafref_xpath_ast.destroy_pointee()
            self.leafref_xpath_ast.free()

    def __str__(self) -> String:
        if self.has_leafref_path:
            return (
                "YangType("
                + self.name
                + ", path="
                + self.leafref_path
                + ", require-instance="
                + ("true" if self.leafref_require_instance else "false")
                + ")"
            )
        if self.has_range:
            return (
                "YangType("
                + self.name
                + ", range="
                + String(self.range_min)
                + ".."
                + String(self.range_max)
                + ")"
            )
        if self.name == "enumeration":
            return (
                "YangType("
                + self.name
                + ", enums="
                + String(len(self.enum_values))
                + ")"
            )
        if self.name == "union":
            return (
                "YangType("
                + self.name
                + ", types="
                + String(len(self.union_types))
                + ")"
            )
        return "YangType(" + self.name + ")"


@fieldwise_init
struct YangMust(Movable):
    ## Represents a YANG `must` expression attached to a leaf.
    ## - expression: raw XPath string from the schema (x-yang.must[].must)
    ## - xpath_ast: parsed XPath AST root when parsed=True; do not dereference when parsed=False.
    ## - parsed: True when parse_xpath succeeded; validator only evaluates when parsed.
    var expression: String
    var error_message: String
    var description: String
    var xpath_ast: Expr.ExprPointer
    var parsed: Bool

    fn __del__(deinit self):
        if self.xpath_ast:
            self.xpath_ast[].free_tree()
            self.xpath_ast.destroy_pointee()
            self.xpath_ast.free()


@fieldwise_init
struct YangWhen(Movable):
    ## Represents a YANG `when` expression attached to a statement.
    var expression: String
    var description: String
    var xpath_ast: Expr.ExprPointer
    var parsed: Bool

    fn __del__(deinit self):
        if self.xpath_ast:
            self.xpath_ast[].free_tree()
            self.xpath_ast.destroy_pointee()
            self.xpath_ast.free()


trait YangHasMustStatements:
    ## Shared access to a (possibly empty) list of `must` constraints.
    def must_count(self) -> Int:
        ...

    def set_must_statements(mut self, var stmts: List[Arc[YangMust]]):
        ...


trait YangHasWhen:
    ## Shared access to an optional `when` constraint.
    def has_when(self) -> Bool:
        ...

    def set_when(mut self, var value: Optional[YangWhen]):
        ...


@fieldwise_init
struct YangLeaf(Movable, JsonDeserializable, YangHasMustStatements, YangHasWhen):
    var name: String
    var type: YangType
    var mandatory: Bool
    var has_default: Bool
    var default_value: String
    var must_statements: List[Arc[YangMust]]
    var when: Optional[YangWhen]

    def must_count(self) -> Int:
        return len(self.must_statements)

    def set_must_statements(mut self, var stmts: List[Arc[YangMust]]):
        self.must_statements = stmts^

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^

    def __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        return (
            "YangLeaf("
            + self.name
            + ", type="
            + self.type.__str__()
            + ", mandatory="
            + m
            + ", has_default="
            + ("true" if self.has_default else "false")
            + ", must="
            + String(len(self.must_statements))
            + ", has_when="
            + ("true" if self.has_when() else "false")
            + ")"
        )


@fieldwise_init
struct YangLeafList(Movable, JsonDeserializable, YangHasMustStatements, YangHasWhen):
    var name: String
    var type: YangType
    var default_values: List[String]
    var must_statements: List[Arc[YangMust]]
    var when: Optional[YangWhen]

    def must_count(self) -> Int:
        return len(self.must_statements)

    def set_must_statements(mut self, var stmts: List[Arc[YangMust]]):
        self.must_statements = stmts^

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^

    def __str__(self) -> String:
        return (
            "YangLeafList("
            + self.name
            + ", type="
            + self.type.__str__()
            + ", defaults="
            + String(len(self.default_values))
            + ", must="
            + String(len(self.must_statements))
            + ", has_when="
            + ("true" if self.has_when() else "false")
            + ")"
        )


@fieldwise_init
struct YangChoiceCase(Movable, JsonDeserializable):
    var name: String
    var node_names: List[String]


@fieldwise_init
struct YangChoice(Movable, JsonDeserializable):
    var name: String
    var mandatory: Bool
    var default_case: String
    var case_names: List[String]
    var cases: List[Arc[YangChoiceCase]]

    def __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        var has_default = "true" if len(self.default_case) > 0 else "false"
        return (
            "YangChoice("
            + self.name
            + ", mandatory="
            + m
            + ", default-case="
            + has_default
            + ", cases="
            + String(len(self.case_names))
            + ")"
        )


@fieldwise_init
struct YangContainer(Movable, JsonDeserializable):
    var name: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __str__(self) -> String:
        var nleaf = len(self.leaves)
        var nleaflist = len(self.leaf_lists)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangContainer(" + self.name + ", leaves=" + String(nleaf) + ", leaf-lists=" + String(nleaflist) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangList(Movable, JsonDeserializable):
    var name: String
    var key: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __str__(self) -> String:
        var nleaf = len(self.leaves)
        var nleaflist = len(self.leaf_lists)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangList(" + self.name + ", key=" + self.key + ", leaves=" + String(nleaf) + ", leaf-lists=" + String(nleaflist) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangModule(Movable, JsonDeserializable):
    ## Minimal YANG module representation for JSON/YANG parsing.
    var name: String
    var namespace: String
    var prefix: String
    ## Module-level `description` (RFC 7950); empty if absent in source.
    var description: String
    ## `revision` date strings in module source order (RFC 7950 allows multiple). Substatements inside each revision block are not modeled.
    var revisions: List[String]
    var organization: String
    var contact: String
    var top_level_containers: List[Arc[YangContainer]]

    def get_name(self) -> String:
        return self.name

    def get_namespace(self) -> String:
        return self.namespace

    def get_prefix(self) -> String:
        return self.prefix

    def get_description(self) -> String:
        return self.description

    def get_revisions(self) -> List[String]:
        return self.revisions.copy()

    def get_organization(self) -> String:
        return self.organization

    def get_contact(self) -> String:
        return self.contact

    ## Returns a copy of the top-level container list; use the `top_level_containers` field when a borrow is enough.
    def get_top_level_containers(self) -> List[Arc[YangContainer]]:
        return self.top_level_containers.copy()

    def __str__(self) -> String:
        return "YangModule(" + self.name + ", namespace=" + self.namespace + ", prefix=" + self.prefix + ", containers=" + String(len(self.top_level_containers)) + ")"
