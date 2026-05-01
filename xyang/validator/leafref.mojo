## Leafref path resolution against a JSON document tree.

from std.collections import Dict

from xyang.json.parser import JsonValue, json_get, json_scalar_text
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import `container`, `leaf`, `list`


comptime TargetSet = Dict[String, Bool]


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


struct LeafrefCache:
    var target_sets: Dict[String, TargetSet]

    def __init__(out self):
        self.target_sets = Dict[String, TargetSet]()

    def contains(
        mut self, read root: JsonValue, target_path: String, value: String
    ) raises -> Bool:
        if target_path not in self.target_sets:
            var values = collect_path_values(root, target_path)
            var target_set = TargetSet()
            for i in range(len(values)):
                target_set[values[i]] = True
            self.target_sets[target_path] = target_set^
        return value in self.target_sets[target_path]


def check_leafrefs_in_object(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    read root: JsonValue,
    path: String,
    json_path: String,
) raises:
    var cache = LeafrefCache()
    check_leafrefs_in_object(data, schema, module, root, path, json_path, cache)


def check_leafrefs_in_object(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    read root: JsonValue,
    path: String,
    json_path: String,
    mut cache: LeafrefCache,
) raises:
    if data.kind != JsonValue.OBJECT:
        return
    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var data_child = module.find_effective_data_child(schema, key)
        if (
            data_child
            and data_child.value()[].spec == `leaf`
            and module.leaf_type(data_child.value()[]) == "leafref"
        ):
            var target_path = module.leafref_path(data_child.value()[])
            var actual = json_scalar_text(slot)
            if not cache.contains(root, target_path, actual):
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
        if data_child and data_child.value()[].spec == `container`:
            check_leafrefs_in_object(
                slot,
                data_child.value()[],
                module,
                root,
                path + "/" + key,
                json_path,
                cache,
            )
        if data_child and data_child.value()[].spec == `list`:
            check_leafrefs_in_list(
                slot,
                data_child.value()[],
                module,
                root,
                path + "/" + key,
                json_path,
                cache,
            )


def check_leafrefs_in_list(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    read root: JsonValue,
    path: String,
    json_path: String,
    mut cache: LeafrefCache,
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
            cache,
        )
