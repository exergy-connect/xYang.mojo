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
    """Supply JSON for each `leaf` under this instance’s modeled container."""

    def json_leaf_value(read self, read leaf_name: String) raises -> JsonValue:
        ...


def _is_json_walk_data_node(read node: YangConstruct) -> Bool:
    from xyang.yang.spec import `container`, `leaf`, `leaf-list`, `list`

    return (
        node.spec == `leaf`
        or node.spec == `leaf-list`
        or node.spec == `container`
        or node.spec == `list`
    )


def json_from_modeled_instance[
    T: YangModeled & JsonFromYangWalkInstance
](read instance: T, read module: YangModule) raises -> JsonValue:
    """Serialize a modeled **instance** to a JSON object for its top container.

    The caller passes the whole `T` value plus the `YangModule` that describes
    it. The implementation walks that module’s direct data children under
    ``T.yang_container_name()`` and fills JSON keys from YANG; leaf values come
    from ``JsonFromYangWalkInstance.json_leaf_value`` on ``instance``.
    """
    from xyang.yang.spec import `container`, `leaf`, `leaf-list`, `list`

    var want = T.yang_container_name()
    var opt = module.top_container(want)
    if not opt:
        raise Error(
            "json_from_modeled_instance: missing top container `" + want + "`"
        )
    ref root = opt.value()[]
    var keys = List[String]()
    var vals = List[Arc[JsonValue]]()
    for ch in root.children:
        if not _is_json_walk_data_node(ch[]):
            continue
        if ch[].spec == `leaf`:
            if not ch[].has_argument():
                continue
            var nm = ch[].argument_text()
            keys.append(nm.copy())
            vals.append(Arc[JsonValue](instance.json_leaf_value(nm)))
            continue
        if (
            ch[].spec == `container`
            or ch[].spec == `list`
            or ch[].spec == `leaf-list`
        ):
            raise Error(
                "json_from_modeled_instance: nested `"
                + ch[].keyword
                + "` `"
                + ch[].argument_text()
                + "` is not supported yet (only direct `leaf` children)",
            )
    return JsonValue(
        JsonValue.OBJECT,
        JsonPayload(JsonObject(keys=keys^, values=vals^)),
        0,
    )


def json_from_instance[
    T: YangModeled & JsonFromYangWalkInstance
](read instance: T, read module: YangModule) raises -> JsonValue:
    """Alias for :func:`json_from_modeled_instance`."""

    return json_from_modeled_instance(instance, module)
