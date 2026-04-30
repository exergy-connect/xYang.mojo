## Leafref path resolution against a JSON document tree.

from xyang.json.parser import JsonValue, json_get, json_scalar_text
from xyang.yang.construct import YangConstruct
from xyang.yang.lookup import (
    find_effective_child,
    find_effective_leaf,
    leaf_type,
    leafref_path,
)


def path_segment_name(segment: String) -> String:
    var base = String(segment.strip())
    var predicate_parts = base.split("[")
    if len(predicate_parts) > 0:
        base = String(predicate_parts[0])
    var prefix_parts = base.split(":")
    if len(prefix_parts) == 2:
        return String(prefix_parts[1])
    return base^


def path_segments(path: String) -> List[String]:
    var out = List[String]()
    var raw_segments = path.split("/")
    for i in range(len(raw_segments)):
        var segment = path_segment_name(String(raw_segments[i]))
        if segment.byte_length() > 0 and segment != ".":
            out.append(segment^)
    return out^


def collect_path_values_at(
    read node: JsonValue,
    read segments: List[String],
    index: Int,
    mut out: List[String],
):
    if node.kind == JsonValue.ARRAY:
        for i in range(len(node.array_values)):
            collect_path_values_at(node.array_values[i][], segments, index, out)
        return

    if index >= len(segments):
        out.append(json_scalar_text(node))
        return

    if node.kind != JsonValue.OBJECT:
        return

    var child = json_get(node, segments[index])
    if child:
        collect_path_values_at(child.value()[], segments, index + 1, out)


def collect_path_values(read root: JsonValue, path: String) -> List[String]:
    var out = List[String]()
    var segments = path_segments(path)
    collect_path_values_at(root, segments, 0, out)
    return out^


def string_in_list(value: String, read values: List[String]) -> Bool:
    for i in range(len(values)):
        if values[i] == value:
            return True
    return False


def check_leafrefs_in_object(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangConstruct,
    read root: JsonValue,
    path: String,
    json_path: String,
) raises:
    if data.kind != JsonValue.OBJECT:
        return
    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var leaf = find_effective_leaf(module, schema, key)
        if leaf and leaf_type(leaf.value()[]) == "leafref":
            var target_path = leafref_path(leaf.value()[])
            var targets = collect_path_values(root, target_path)
            var actual = json_scalar_text(slot)
            if not string_in_list(actual, targets):
                var pfx = String()
                if json_path.byte_length() > 0:
                    pfx += json_path + " "
                if slot.source_line > 0:
                    pfx += "line " + String(slot.source_line) + ": "
                raise Error(
                    pfx
                    + path
                    + "/"
                    + key
                    + ": leafref `"
                    + actual
                    + "` does not resolve"
                )
        var container = find_effective_child(module, schema, "container", key)
        if container:
            check_leafrefs_in_object(
                slot,
                container.value()[],
                module,
                root,
                path + "/" + key,
                json_path,
            )
        var list_node = find_effective_child(module, schema, "list", key)
        if list_node:
            check_leafrefs_in_list(
                slot,
                list_node.value()[],
                module,
                root,
                path + "/" + key,
                json_path,
            )


def check_leafrefs_in_list(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangConstruct,
    read root: JsonValue,
    path: String,
    json_path: String,
) raises:
    if data.kind != JsonValue.ARRAY:
        return
    for i in range(len(data.array_values)):
        check_leafrefs_in_object(
            data.array_values[i][],
            schema,
            module,
            root,
            path + "[" + String(i) + "]",
            json_path,
        )
