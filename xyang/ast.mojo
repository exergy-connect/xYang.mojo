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


@fieldwise_init
struct YangStatementWithMust(Movable):
    ## Python parity: base holder for statements that support must.
    var must_statements: List[Arc[YangMust]]


@fieldwise_init
struct YangStatementWithWhen(Movable):
    ## Python parity: base holder for statements that support when.
    var has_when: Bool
    var when_statement: YangWhen


@fieldwise_init
struct YangLeaf(Movable, JsonDeserializable):
    var name: String
    var type: YangType
    var mandatory: Bool
    var with_must: YangStatementWithMust
    var with_when: YangStatementWithWhen

    def __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        return (
            "YangLeaf("
            + self.name
            + ", type="
            + self.type.__str__()
            + ", mandatory="
            + m
            + ", must="
            + String(len(self.with_must.must_statements))
            + ", has_when="
            + ("true" if self.with_when.has_when else "false")
            + ")"
        )


@fieldwise_init
struct YangChoice(Movable, JsonDeserializable):
    var name: String
    var mandatory: Bool
    var case_names: List[String]

    def __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        return "YangChoice(" + self.name + ", mandatory=" + m + ", cases=" + String(len(self.case_names)) + ")"


@fieldwise_init
struct YangContainer(Movable, JsonDeserializable):
    var name: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __str__(self) -> String:
        var nleaf = len(self.leaves)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangContainer(" + self.name + ", leaves=" + String(nleaf) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangList(Movable, JsonDeserializable):
    var name: String
    var key: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __str__(self) -> String:
        var nleaf = len(self.leaves)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangList(" + self.name + ", key=" + self.key + ", leaves=" + String(nleaf) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangModule(Movable, JsonDeserializable):
    ## Minimal YANG module representation for JSON/YANG parsing.
    var name: String
    var namespace: String
    var prefix: String
    var top_level_containers: List[Arc[YangContainer]]

    def __str__(self) -> String:
        return "YangModule(" + self.name + ", namespace=" + self.namespace + ", prefix=" + self.prefix + ", containers=" + String(len(self.top_level_containers)) + ")"
