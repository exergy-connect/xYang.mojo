## Runtime JSON for xYang modeled **instances** by walking the module YANG tree.

from std.collections import List
from std.memory import ArcPointer

from xyang.json.value import (
    JsonObject,
    JsonPayload,
    JsonValue,
)
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule

from .types import YangModeled

comptime Arc = ArcPointer


trait JsonFromYangWalkInstance(Movable):
    """Supply JSON for leaves and nested data nodes under this instance."""

    def json_leaf_value(read self, read leaf_name: String) raises -> JsonValue:
        ...

    def json_nested_value(
        read self,
        read child_keyword: String,
        read child_name: String,
        read module: YangModule,
        read child_node: YangConstruct,
    ) raises -> JsonValue:
        ...


def _is_json_walk_data_node(read node: YangConstruct) -> Bool:
    from xyang.yang.spec import `container`, `leaf`, `leaf-list`, `list`

    return (
        node.spec == `leaf`
        or node.spec == `leaf-list`
        or node.spec == `container`
        or node.spec == `list`
    )


def _json_from_construct_node[
    T: JsonFromYangWalkInstance
](
    read instance: T,
    read module: YangModule,
    read root_node: YangConstruct,
) raises -> JsonValue:
    from xyang.yang.spec import `container`, `leaf`, `leaf-list`, `list`

    var keys = List[String]()
    var vals = List[Arc[JsonValue]]()
    for ch in root_node.children:
        if not _is_json_walk_data_node(ch[]):
            continue
        if not ch[].has_argument():
            continue
        var nm = ch[].argument_text()
        if ch[].spec == `leaf`:
            keys.append(nm.copy())
            vals.append(Arc[JsonValue](instance.json_leaf_value(nm)))
            continue
        if ch[].spec == `container`:
            keys.append(nm.copy())
            vals.append(
                Arc[JsonValue](
                    instance.json_nested_value(
                        "container", nm, module, ch[]
                    )
                )
            )
            continue
        if ch[].spec == `list` or ch[].spec == `leaf-list`:
            keys.append(nm.copy())
            vals.append(
                Arc[JsonValue](
                    instance.json_nested_value(
                        ch[].keyword, nm, module, ch[]
                    )
                )
            )
            continue
        raise Error(
            "json_from_modeled_instance: unsupported child `"
            + ch[].keyword
            + "`",
        )
    return JsonValue(
        JsonValue.OBJECT,
        JsonPayload(JsonObject(keys=keys^, values=vals^)),
        0,
    )


def json_from_modeled_instance[
    T: YangModeled & JsonFromYangWalkInstance
](read instance: T, read module: YangModule) raises -> JsonValue:
    """Serialize a modeled **instance** to JSON for its top container.

    Walks the ``YangConstruct`` subtree for ``T.yang_container_name()`` in
    ``module`` and projects JSON keys from that IR. Leaf values come from
    ``json_leaf_value``; nested ``container`` / ``list`` / ``leaf-list`` nodes
    from ``json_nested_value`` (typically delegating back into this walker).
    """
    var want = T.yang_container_name()
    var opt = module.top_container(want)
    if not opt:
        raise Error(
            "json_from_modeled_instance: missing top container `" + want + "`"
        )
    return _json_from_construct_node(instance, module, opt.value()[])


def json_from_instance[
    T: YangModeled & JsonFromYangWalkInstance
](read instance: T, read module: YangModule) raises -> JsonValue:
    """Alias for :func:`json_from_modeled_instance`."""

    return json_from_modeled_instance(instance, module)
