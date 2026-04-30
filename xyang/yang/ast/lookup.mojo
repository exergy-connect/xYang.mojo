## Navigate `YangConstruct` trees for validation (groupings, leaves, types).

from std.memory import ArcPointer

from xyang.yang.arguments import RangeBounds, try_parse_range_bounds
from xyang.yang.ast.construct import YangConstruct


comptime Arc = ArcPointer


def find_child(
    read node: YangConstruct, keyword: String
) -> Optional[Arc[YangConstruct]]:
    for child in node.children:
        if child[].keyword == keyword:
            return Optional[Arc[YangConstruct]](child.copy())
    return Optional[Arc[YangConstruct]]()


def find_grouping(
    read module: YangConstruct, name: String
) -> Optional[Arc[YangConstruct]]:
    for child in module.children:
        if (
            child[].keyword == "grouping"
            and child[].argument
            and child[].argument.value() == name
        ):
            return Optional[Arc[YangConstruct]](child.copy())
    return Optional[Arc[YangConstruct]]()


def is_leaf_name_in_uses(
    read module: YangConstruct, read parent: YangConstruct, name: String
) -> Bool:
    for child in parent.children:
        if child[].keyword != "uses" or not child[].argument:
            continue
        var grouping = find_grouping(module, child[].argument.value())
        if not grouping:
            continue
        for gchild in grouping.value()[].children:
            if (
                gchild[].keyword == "leaf"
                and gchild[].argument
                and gchild[].argument.value() == name
            ):
                return True
    return False


def find_effective_leaf(
    read module: YangConstruct,
    read parent: YangConstruct,
    name: String,
) -> Optional[Arc[YangConstruct]]:
    for child in parent.children:
        if (
            child[].keyword == "leaf"
            and child[].argument
            and child[].argument.value() == name
        ):
            return Optional[Arc[YangConstruct]](child.copy())
    for child in parent.children:
        if child[].keyword != "uses" or not child[].argument:
            continue
        var grouping = find_grouping(module, child[].argument.value())
        if not grouping:
            continue
        var leaf = find_effective_leaf(module, grouping.value()[], name)
        if leaf:
            return leaf^
    return Optional[Arc[YangConstruct]]()


def find_effective_child(
    read module: YangConstruct,
    read parent: YangConstruct,
    keyword: String,
    name: String,
) -> Optional[Arc[YangConstruct]]:
    for child in parent.children:
        if (
            child[].keyword == keyword
            and child[].argument
            and child[].argument.value() == name
        ):
            return Optional[Arc[YangConstruct]](child.copy())
    return Optional[Arc[YangConstruct]]()


def leaf_type(read leaf: YangConstruct) -> String:
    var ty = find_child(leaf, "type")
    if ty and ty.value()[].argument:
        return ty.value()[].argument.value()
    return ""


def leaf_range(read leaf: YangConstruct) -> String:
    var ty = find_child(leaf, "type")
    if not ty:
        return ""
    var range_stmt = find_child(ty.value()[], "range")
    if range_stmt and range_stmt.value()[].argument:
        return range_stmt.value()[].argument.value()
    return ""


def leaf_range_bounds(read leaf: YangConstruct) raises -> Optional[RangeBounds]:
    var text = leaf_range(leaf)
    if text.byte_length() == 0:
        return Optional[RangeBounds]()
    return try_parse_range_bounds(text)


def leafref_path(read leaf: YangConstruct) -> String:
    var ty = find_child(leaf, "type")
    if not ty:
        return ""
    var path_stmt = find_child(ty.value()[], "path")
    if path_stmt and path_stmt.value()[].argument:
        return path_stmt.value()[].argument.value()
    return ""
