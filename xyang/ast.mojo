## Minimal YANG AST model in Mojo for xYang.mojo.

from std.memory import ArcPointer

comptime Arc = ArcPointer


@fieldwise_init
struct YangType(Movable):
    var name: String


@fieldwise_init
struct YangLeaf(Movable):
    var name: String
    var type: YangType
    var mandatory: Bool


@fieldwise_init
struct YangContainer(Movable):
    var name: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var containers: List[Arc[YangContainer]]


@fieldwise_init
struct YangModule(Movable):
    ## Minimal YANG module representation for JSON/YANG parsing.
    var name: String
    var namespace: String
    var prefix: String
    var top_level_containers: List[Arc[YangContainer]]

