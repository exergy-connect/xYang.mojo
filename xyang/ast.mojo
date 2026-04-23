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

    def __str__(self) -> String:
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
struct YangLeaf(Movable, JsonDeserializable):
    var name: String
    var type: YangType
    var mandatory: Bool
    ## Zero or more must expressions (parsed from x-yang.must[]).
    var must: List[Arc[YangMust]]

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
            + String(len(self.must))
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
