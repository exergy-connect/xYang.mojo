from std.memory import ArcPointer
from xyang.ast import (
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangLeafList,
    YangAnydata,
    YangAnyxml,
)

comptime Arc = ArcPointer


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
