## Helpers for binding explicit type-level xYang schemas to YANG modules.

from std.memory import ArcPointer

from xyang.json.parser import parse_json
from xyang.json.value import JsonValue
from xyang.validator.document import validate_data
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule

from .types import (
    YangDataNodeSpec,
    LeafModelSpec,
    NodeModelSpec,
    YangList,
    YangListItem,
    YangModeled,
)


comptime Arc = ArcPointer


def _stmt(keyword: String, argument: String = "") -> YangConstruct:
    var node = YangConstruct(keyword, 0)
    if argument.byte_length() > 0:
        node.set_raw_argument(argument)
    return node^


def _append_stmt(mut parent: YangConstruct, var child: YangConstruct):
    parent.children.append(Arc[YangConstruct](child^))


def _append_arg(mut parent: YangConstruct, keyword: String, argument: String):
    if argument.byte_length() == 0:
        return
    var child = _stmt(keyword, argument)
    _append_stmt(parent, child^)


def find_module_top_data_node(
    read module: YangModule, read name: String
) raises -> Optional[Arc[YangConstruct]]:
    """Top-level ``container`` or ``list`` node with argument ``name``."""

    var opt = module.top_container(name)
    if opt:
        return opt
    from xyang.yang.spec import `container`, `list`

    ref root = module.root_construct()
    for child in root[].children:
        if not child[].has_argument():
            continue
        if child[].argument_text() != name:
            continue
        if child[].spec == `container` or child[].spec == `list`:
            return Optional[Arc[YangConstruct]](child.copy())
    return Optional[Arc[YangConstruct]]()


def validate_yang_subtree[T: YangModeled](read module: YangModule) raises:
    var want = T.yang_container_name()
    var actual = find_module_top_data_node(module, want)
    if not actual:
        raise Error(
            "model: Yang subtree missing top container `" + want + "`"
        )
    var generated = yang_module_from_model[T](
        module.get_name(), module.get_namespace(), module.get_prefix()
    )
    var expected = find_module_top_data_node(generated, want)
    if not expected:
        raise Error(
            "model: generated schema missing top container `" + want + "`"
        )
    if actual.value()[].format(0) != expected.value()[].format(0):
        raise Error(
            "model: generated container `"
            + want
            + "` does not match module container `"
            + want
            + "`"
        )


def list_construct_from_entry[T: YangListItem]() raises -> YangConstruct:
    """Build a top-level ``list`` node for list entry type ``T``."""

    var node = _stmt("list", T.yang_container_name())
    var key = String(T.LIST_KEY)
    if key.byte_length() > 0:
        _append_arg(node, "key", key)
    T.append_model_fields(node)
    return node^


def yang_module_from_list_entry[T: YangListItem](
    module_name: String,
    namespace: String,
    prefix: String,
    yang_version: String = "1.1",
) raises -> YangModule:
    """Build a ``module`` whose sole top-level data node is ``list`` ``T``."""

    var root = _stmt("module", module_name)
    _append_arg(root, "yang-version", yang_version)
    _append_arg(root, "namespace", namespace)
    _append_arg(root, "prefix", prefix)
    _append_stmt(root, list_construct_from_entry[T]()^)
    var module = YangModule()
    module.ingest_construct_tree(root^)
    return module^


def validate_yang_subtree_list[T: YangListItem](read module: YangModule) raises:
    var want = T.yang_container_name()
    var actual = find_module_top_data_node(module, want)
    if not actual:
        raise Error(
            "model: Yang subtree missing top list `" + want + "`"
        )
    var generated = yang_module_from_list_entry[T](
        module.get_name(), module.get_namespace(), module.get_prefix()
    )
    var expected = find_module_top_data_node(generated, want)
    if not expected:
        raise Error(
            "model: generated schema missing top list `" + want + "`"
        )
    if actual.value()[].format(0) != expected.value()[].format(0):
        raise Error(
            "model: generated list `"
            + want
            + "` does not match module list `"
            + want
            + "`"
        )


def _append_leaf_constraints[FT: NodeModelSpec](mut node: YangConstruct):
    if FT.has_yang_when():
        _append_stmt(node, _stmt("when", FT.yang_when_condition()))
    comptime for i in range(FT.yang_must_count()):
        _append_stmt(node, _stmt("must", FT.yang_must_condition[i]()))


def _append_node_constraints[FT: NodeModelSpec](mut node: YangConstruct):
    if FT.has_yang_when():
        _append_stmt(node, _stmt("when", FT.yang_when_condition()))
    comptime for i in range(FT.yang_must_count()):
        _append_stmt(node, _stmt("must", FT.yang_must_condition[i]()))


def _append_type_constraints_from_model[
    FT: YangDataNodeSpec & LeafModelSpec
](
    mut type_node: YangConstruct, read yt: String
):
    if yt == "enumeration":
        comptime for i in range(FT.yang_enum_count()):
            _append_arg(type_node, "enum", FT.yang_enum_value[i]())
    elif yt == "string":
        var max_len = FT.model_max_string_length()
        if max_len >= 0:
            _append_arg(type_node, "length", "0.." + String(max_len))
        comptime for i in range(FT.yang_pattern_count()):
            _append_arg(type_node, "pattern", FT.yang_pattern_text[i]())
    else:
        if FT.has_model_range():
            _append_arg(
                type_node,
                "range",
                String(FT.model_range_min())
                + ".."
                + String(FT.model_range_max()),
            )


def _leaf_from_model[
    FT: YangDataNodeSpec & LeafModelSpec
](read name: String) raises -> YangConstruct:
    var leaf_node = _stmt("leaf", name)
    var yt = FT.yang_type_str()
    var type_node = _stmt("type", yt)
    _append_type_constraints_from_model[FT](type_node, yt)
    _append_stmt(leaf_node, type_node^)
    _append_leaf_constraints[FT](leaf_node)
    return leaf_node^


def _leaf_list_from_model[
    FT: YangDataNodeSpec & LeafModelSpec
](read name: String) raises -> YangConstruct:
    var node = _stmt("leaf-list", name)
    var yt = FT.yang_type_str()
    var type_node = _stmt("type", yt)
    _append_type_constraints_from_model[FT](type_node, yt)
    _append_stmt(node, type_node^)
    _append_leaf_constraints[FT](node)
    return node^


def _container_from_model_field[
    FT: YangDataNodeSpec & LeafModelSpec
](
    read name: String
) raises -> YangConstruct:
    var node = _stmt("container", name)
    _append_node_constraints[FT](node)
    FT.ChildType.append_model_fields(node)
    return node^


def _list_from_model_field[
    FT: YangDataNodeSpec & LeafModelSpec
](
    read name: String
) raises -> YangConstruct:
    var node = _stmt("list", name)
    var key = String(FT.EntryType.LIST_KEY)
    if key.byte_length() > 0:
        _append_arg(node, "key", key)
    _append_node_constraints[FT](node)
    FT.EntryType.append_model_fields(node)
    return node^


def construct_from_model_field[
    FT: YangDataNodeSpec & LeafModelSpec
](
    read name: String, read field: FT
) raises -> YangConstruct:
    comptime kind = FT.yang_node_kind()
    comptime if kind == "leaf":
        return _leaf_from_model[FT](name)
    elif kind == "leaf-list":
        return _leaf_list_from_model[FT](name)
    elif kind == "container":
        return _container_from_model_field[FT](name)
    elif kind == "list":
        return _list_from_model_field[FT](name)
    else:
        raise Error("model: unsupported model node kind `" + kind + "`")


def container_construct_from_model[T: YangModeled]() raises -> YangConstruct:
    var container = _stmt("container", T.yang_container_name())
    T.append_model_fields(container)
    return container^


trait YangModuleSketch:
    """Lower multiple top-level ``container`` / ``list`` nodes into one ``module``."""

    @staticmethod
    def append_containers_to_module(mut module_root: YangConstruct) raises:
        ...


def yang_module_from_sketch[
    T: YangModeled & YangModuleSketch,
](
    module_name: String,
    namespace: String,
    prefix: String,
    yang_version: String = "1.1",
) raises -> YangModule:
    """Build one ``module`` with multiple top-level data nodes from sketch ``T``."""

    var root = _stmt("module", module_name)
    _append_arg(root, "yang-version", yang_version)
    _append_arg(root, "namespace", namespace)
    _append_arg(root, "prefix", prefix)
    T.append_containers_to_module(root)
    var module = YangModule()
    module.ingest_construct_tree(root^)
    return module^


def yang_module_from_model[T: YangModeled](
    module_name: String,
    namespace: String,
    prefix: String,
    yang_version: String = "1.1",
) raises -> YangModule:
    var root = _stmt("module", module_name)
    _append_arg(root, "yang-version", yang_version)
    _append_arg(root, "namespace", namespace)
    _append_arg(root, "prefix", prefix)
    var container = container_construct_from_model[T]()
    _append_stmt(root, container^)
    var module = YangModule()
    module.ingest_construct_tree(root^)
    return module^


def validate_data_against_model[T: YangModeled](
    read data: JsonValue,
    module_name: String,
    namespace: String,
    prefix: String,
    json_path: String = "",
) raises:
    var module = yang_module_from_model[T](module_name, namespace, prefix)
    validate_data(data, module, json_path)


def parse_and_validate_json_against_model[T: YangModeled](
    source: String,
    module_name: String,
    namespace: String,
    prefix: String,
    json_path: String = "",
) raises -> JsonValue:
    var data = parse_json(source, json_path)
    validate_data_against_model[T](
        data, module_name, namespace, prefix, json_path
    )
    return data^
