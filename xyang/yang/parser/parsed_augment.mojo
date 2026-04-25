from std.memory import ArcPointer
import xyang.ast as ast

comptime Arc = ArcPointer
comptime YangContainer = ast.YangContainer
comptime YangList = ast.YangList
comptime YangChoice = ast.YangChoice
comptime YangLeaf = ast.YangLeaf
comptime YangLeafList = ast.YangLeafList
comptime YangAnydata = ast.YangAnydata
comptime YangAnyxml = ast.YangAnyxml


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
