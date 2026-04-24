from std.memory import ArcPointer
from std.utils import Variant
from xyang.ast import (
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangLeafList,
    YangAnydata,
    YangAnyxml,
)
from xyang.yang.parser.yang_token import YangToken

comptime Arc = ArcPointer


@fieldwise_init
struct ParsedGrouping(Movable):
    ## Keep Arc at the Variant arm level: YANG AST nodes are not ImplicitlyCopyable.
    ## Wrapping nodes in Arc lets grouping entries be stored/reused without move-only copy errors.
    comptime ChildStatement = Variant[
        Arc[YangLeaf],
        Arc[YangLeafList],
        Arc[YangAnydata],
        Arc[YangAnyxml],
        Arc[YangContainer],
        Arc[YangList],
        Arc[YangChoice],
    ]
    var name: String
    var children: List[Self.ChildStatement]
