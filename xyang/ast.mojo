## Minimal YANG AST model in Mojo for xYang.mojo.

from std.memory import ArcPointer

comptime Arc = ArcPointer


@fieldwise_init
struct YangType(Movable, Stringable):
    var name: String

    fn __str__(self) -> String:
        return "YangType(" + self.name + ")"


@fieldwise_init
struct YangLeaf(Movable, Stringable):
    var name: String
    var type: YangType
    var mandatory: Bool

    fn __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        return "YangLeaf(" + self.name + ", type=" + String(self.type) + ", mandatory=" + m + ")"


@fieldwise_init
struct YangChoice(Movable, Stringable):
    var name: String
    var mandatory: Bool
    var case_names: List[String]

    fn __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        return "YangChoice(" + self.name + ", mandatory=" + m + ", cases=" + String(len(self.case_names)) + ")"


@fieldwise_init
struct YangContainer(Movable, Stringable):
    var name: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    fn __str__(self) -> String:
        var nleaf = len(self.leaves)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangContainer(" + self.name + ", leaves=" + String(nleaf) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangList(Movable, Stringable):
    var name: String
    var key: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    fn __str__(self) -> String:
        var nleaf = len(self.leaves)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangList(" + self.name + ", key=" + self.key + ", leaves=" + String(nleaf) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangModule(Movable, Stringable):
    ## Minimal YANG module representation for JSON/YANG parsing.
    var name: String
    var namespace: String
    var prefix: String
    var top_level_containers: List[Arc[YangContainer]]

    fn __str__(self) -> String:
        return "YangModule(" + self.name + ", namespace=" + self.namespace + ", prefix=" + self.prefix + ", containers=" + String(len(self.top_level_containers)) + ")"

