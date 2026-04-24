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
from xyang.yang.parser.types import ParsedGrouping
from xyang.yang.parser.clone_utils import (
    clone_leaf_arc_impl,
    clone_leaf_list_arc_impl,
    clone_anydata_arc_impl,
    clone_anyxml_arc_impl,
    clone_container_arc_impl,
    clone_list_arc_impl,
    clone_choice_arc_impl,
)

comptime Arc = ArcPointer


def find_grouping_index_impl(read grouping_names: List[String], grouping_name: String) -> Int:
    for i in range(len(grouping_names)):
        if grouping_names[i] == grouping_name:
            return i
    return -1


def store_grouping_impl(
    mut grouping_names: List[String],
    mut groupings: List[Arc[ParsedGrouping]],
    var grouping: ParsedGrouping,
) -> Bool:
    if find_grouping_index_impl(grouping_names, grouping.name) >= 0:
        return False
    grouping_names.append(grouping.name)
    groupings.append(Arc[ParsedGrouping](grouping^))
    return True


def append_grouping_nodes_by_name_impl(
    read grouping_names: List[String],
    read groupings: List[Arc[ParsedGrouping]],
    grouping_name: String,
    mut leaves: List[Arc[YangLeaf]],
    mut leaf_lists: List[Arc[YangLeafList]],
    mut anydatas: List[Arc[YangAnydata]],
    mut anyxmls: List[Arc[YangAnyxml]],
    mut containers: List[Arc[YangContainer]],
    mut lists: List[Arc[YangList]],
    mut choices: List[Arc[YangChoice]],
) -> Bool:
    var idx = find_grouping_index_impl(grouping_names, grouping_name)
    if idx < 0:
        return False
    for i in range(len(groupings[idx][].children)):
        var child = groupings[idx][].children[i]
        if child.isa[Arc[YangLeaf]]():
            leaves.append(clone_leaf_arc_impl(child[Arc[YangLeaf]]))
        elif child.isa[Arc[YangLeafList]]():
            leaf_lists.append(clone_leaf_list_arc_impl(child[Arc[YangLeafList]]))
        elif child.isa[Arc[YangAnydata]]():
            anydatas.append(clone_anydata_arc_impl(child[Arc[YangAnydata]]))
        elif child.isa[Arc[YangAnyxml]]():
            anyxmls.append(clone_anyxml_arc_impl(child[Arc[YangAnyxml]]))
        elif child.isa[Arc[YangContainer]]():
            containers.append(clone_container_arc_impl(child[Arc[YangContainer]]))
        elif child.isa[Arc[YangList]]():
            lists.append(clone_list_arc_impl(child[Arc[YangList]]))
        elif child.isa[Arc[YangChoice]]():
            choices.append(clone_choice_arc_impl(child[Arc[YangChoice]]))
    return True
