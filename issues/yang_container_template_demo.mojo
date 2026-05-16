## Standalone: variadic `YangContainer` + homogeneous `YangField` pack → `YangConstruct` IR,
## bridged to `OpenRouterFunction` and parameters JSON Schema via `xyang`.
##
## Run (after `pixi run package`):
##   pixi run mojo -I build -I . -I examples/openrouter_demo issues/yang_container_template_demo.mojo
##
## Every member of `*Fields` is a homogeneous `YangField[...]` (leaf or nested
## container). Nested fields set `Child=` and `Runtime=` to the nested
## `YangContainer[...]` type. `schema_stmt()` is schema-only; `to_ast(self)`
## lowers the instance `values` tuple into the same IR shape (adds `value` leaves).
##
## Initialize with `Container(values=(...))` — one tuple, field order matches
## `*Fields` (nested slots take a fully-built child `YangContainer`).

from std.builtin.variadics import TypeList
from std.memory import ArcPointer

from xyang.api import (
    MaxStringLength,
    YangBuiltinString,
    YangBuiltinUInt16,
    YangConstraints,
    YangContainer as ApiYangContainer,
    YangEnum,
    YangField as ApiYangField,
    YangLeaf,
    YangListModel,
    YangModel,
    YangModeled,
    json_from_modeled_instance,
    validate_yang_subtree,
    yang_module_from_sketch,
)
from xyang.json import yang_json_schema_for_modeled_list_entry
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule

from open_router import OpenRouterFunction

comptime Arc = ArcPointer

comptime LEAF_KIND = "leaf"
comptime CONTAINER_KIND = "container"


def _stmt(keyword: String, argument: String = "") -> YangConstruct:
    var node = YangConstruct(keyword, 0)
    if argument.byte_length() > 0:
        node.set_raw_argument(argument)
    return node^


def _append_stmt(mut parent: YangConstruct, var child: YangConstruct):
    parent.children.append(Arc[YangConstruct](child^))


def _leaf_schema_stmt(read name: String, read type_name: String) raises -> YangConstruct:
    var leaf_node = _stmt("leaf", name)
    var type_node = _stmt("type", type_name)
    _append_stmt(leaf_node, type_node^)
    return leaf_node^


def _leaf_instance_stmt(
    read name: String, read type_name: String, read value_text: String
) raises -> YangConstruct:
    var leaf_node = _leaf_schema_stmt(name, type_name)
    _append_stmt(leaf_node, _stmt("value", value_text))
    return leaf_node^


trait YangFieldChildSpec(Defaultable, ImplicitlyDestructible, Movable):
    @staticmethod
    def schema_stmt() raises -> YangConstruct:
        ...

    def instance_to_ast(read self) raises -> YangConstruct:
        ...

    def set_by_name[
        field_name: StaticString,
        Value: Copyable & Defaultable & ImplicitlyDestructible & Movable,
    ](mut self, var value: Value) raises:
        ...


struct _NoChild(YangFieldChildSpec):
    def __init__(out self):
        pass

    @staticmethod
    def schema_stmt() raises -> YangConstruct:
        raise Error("YangField: leaf field has no Child container")

    def set_by_name[
        field_name: StaticString,
        Value: Copyable & Defaultable & ImplicitlyDestructible & Movable,
    ](mut self, var value: Value) raises:
        _ = field_name
        _ = value
        raise Error("YangField: leaf field has no Child container")

    def instance_to_ast(read self) raises -> YangConstruct:
        _ = self
        raise Error("YangField: leaf field has no Child container")


trait YangFieldSpec:
    comptime RuntimeValue: Movable & Defaultable & ImplicitlyDestructible
    comptime ChildBody: YangFieldChildSpec = _NoChild

    @staticmethod
    def yang_name() -> String:
        ...

    @staticmethod
    def is_container() -> Bool:
        ...

    @staticmethod
    def leaf_type_str() -> String:
        ...

    @staticmethod
    def schema_stmt() raises -> YangConstruct:
        ...


struct YangField[
    name: StaticString,
    kind: StaticString,
    leaf_type: StaticString,
    Child: YangFieldChildSpec = _NoChild,
    Runtime: Movable & Defaultable & ImplicitlyDestructible = String,
](YangFieldSpec):
    comptime RuntimeValue = Self.Runtime
    comptime ChildBody = Self.Child

    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def is_container() -> Bool:
        return String(Self.kind) == CONTAINER_KIND

    @staticmethod
    def leaf_type_str() -> String:
        return String(Self.leaf_type)

    @staticmethod
    def schema_stmt() raises -> YangConstruct:
        comptime if Self.is_container():
            return Self.Child.schema_stmt()
        else:
            return _leaf_schema_stmt(Self.yang_name(), Self.leaf_type_str())


comptime YangString[name: StaticString] = YangField[
    name, LEAF_KIND, "string", Runtime=String
]
comptime YangUInt16[name: StaticString] = YangField[
    name, LEAF_KIND, "uint16", Runtime=Int
]
comptime YangInt = YangUInt16

comptime FieldRuntimeValue[Field: YangFieldSpec] = Field.RuntimeValue


struct _YangContainerSchema[
    name: StaticString,
    *Fields: YangFieldSpec,
]:
    @staticmethod
    def yang_name() -> String:
        return String(Self.name)

    @staticmethod
    def field_count() -> Int:
        return len(Self.Fields)

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Fields[i].yang_name()


struct YangContainer[
    name: StaticString,
    *Fields: YangFieldSpec,
](
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    YangFieldChildSpec,
    YangModeled,
):
    comptime Schema = _YangContainerSchema[Self.name, *Self.Fields]
    comptime ValueTypes = TypeList.of[
        Trait=YangFieldSpec, *Self.Fields
    ]().map[
        ToTrait=Movable & Defaultable & ImplicitlyDestructible,
        FieldRuntimeValue,
    ]()

    var values: Tuple[*Self.ValueTypes]

    def __init__(out self):
        comptime assert Self.Schema.field_count() == len(Self.Fields)
        comptime for i in range(len(Self.Fields)):
            comptime assert (
                Self.Schema.field_name[i]() == Self.Fields[i].yang_name()
            )
        self.values = Tuple[*Self.ValueTypes]()

    def __init__(out self, *, var values: Tuple[*Self.ValueTypes]):
        comptime assert Self.Schema.field_count() == len(Self.Fields)
        comptime for i in range(len(Self.Fields)):
            comptime assert (
                Self.Schema.field_name[i]() == Self.Fields[i].yang_name()
            )
        self.values = values^

    @staticmethod
    def yang_container_name() -> String:
        return String(Self.name)

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    @staticmethod
    def field_count() -> Int:
        return Self.Schema.field_count()

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Schema.field_name[i]()

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        comptime for i in range(len(Self.Fields)):
            var child = Self.Fields[i].schema_stmt()
            _append_stmt(parent, child^)

    @staticmethod
    def schema_stmt() raises -> YangConstruct:
        var container = _stmt("container", String(Self.name))
        comptime for i in range(len(Self.Fields)):
            var child = Self.Fields[i].schema_stmt()
            _append_stmt(container, child^)
        return container^

    def set[i: Int](mut self, var value: Self.ValueTypes[i]):
        comptime assert i >= 0 and i < len(Self.Fields)
        self.values[i] = value^

    @staticmethod
    def field_index[field_name: StaticString]() -> Int:
        comptime for i in range(len(Self.Fields)):
            comptime if String(field_name) == Self.Schema.field_name[i]():
                return i
        return -1

    def set_by_name[
        field_name: StaticString,
        Value: Copyable & Defaultable & ImplicitlyDestructible & Movable,
    ](
        mut self, var value: Value
    ) raises:
        comptime i = Self.field_index[field_name]()
        comptime assert i >= 0, "unknown schema field"
        comptime assert not Self.Fields[i].is_container(), (
            "field is a nested container; use set_in_nested"
        )
        self.set[i](rebind_var[Self.ValueTypes[i]](value^))

    def set_in_nested[
        container_name: StaticString,
        field_name: StaticString,
        Value: Copyable & Defaultable & ImplicitlyDestructible & Movable,
    ](mut self, var value: Value) raises:
        comptime ci = Self.field_index[container_name]()
        comptime assert ci >= 0, "unknown nested container"
        comptime assert Self.Fields[ci].is_container(), (
            "field is a leaf, not a nested container"
        )
        _set_nested_value[Self.Fields[ci].ChildBody, field_name](
            rebind[Self.Fields[ci].ChildBody](self.values[ci]), value^
        )

    def instance_to_ast(read self) raises -> YangConstruct:
        return self.to_ast()

    def _append_instance_field[i: Int](read self, mut container: YangConstruct) raises:
        comptime field = Self.Fields[i]
        comptime if field.is_container():
            _append_stmt(
                container,
                rebind[field.ChildBody](self.values[i]).instance_to_ast()^,
            )
        comptime if (
            not field.is_container() and String(field.leaf_type_str()) == "string"
        ):
            _append_stmt(
                container,
                _leaf_instance_stmt(
                    field.yang_name(),
                    field.leaf_type_str(),
                    String(rebind[String](self.values[i])),
                ),
            )
        comptime if (
            not field.is_container() and String(field.leaf_type_str()) != "string"
        ):
            _append_stmt(
                container,
                _leaf_instance_stmt(
                    field.yang_name(),
                    field.leaf_type_str(),
                    String(rebind[Int](self.values[i])),
                ),
            )

    def to_ast(read self) raises -> YangConstruct:
        var container = _stmt("container", String(Self.name))
        comptime for i in range(len(Self.Fields)):
            self._append_instance_field[i](container)
        return container^


def _set_nested_value[
    Body: YangFieldChildSpec,
    field_name: StaticString,
    Value: Copyable & Defaultable & ImplicitlyDestructible & Movable,
](mut slot: Body, var value: Value) raises:
    slot.set_by_name[field_name](value^)


comptime InnerBody = YangContainer[
    "inner_params",
    YangInt["count"],
]

comptime InnerParams = YangField[
    "inner_params",
    CONTAINER_KIND,
    "",
    Child=InnerBody,
    Runtime=InnerBody,
]

comptime MiniParamsTemplate = YangContainer[
    "mini_params",
    YangString["ping"],
    InnerParams,
    YangInt["pong"],
]

comptime InnerParamsModel = YangModel[
    "inner_params",
    ApiYangField["count", YangLeaf[YangBuiltinUInt16]],
]

comptime MiniParamEntry = YangListModel[
    "mini_params",
    "ping",
    ApiYangField["ping", YangLeaf[YangBuiltinString]],
    ApiYangField["inner_params", ApiYangContainer[InnerParamsModel]],
    ApiYangField["pong", YangLeaf[YangBuiltinUInt16]],
]

comptime OPENROUTER_TOOL_DESCRIPTION = (
    "Template mini tool: ping, nested inner_params.count, pong."
)
comptime MiniFn = OpenRouterFunction[
    "echo",
    OPENROUTER_TOOL_DESCRIPTION,
    MiniParamEntry,
]


def main() raises:
    var module = yang_module_from_sketch[MiniFn](
        "openrouter-template-demo",
        "urn:example:openrouter-template-demo",
        "otd",
    )
    MiniFn.comptime_validate(module)
    var params_schema = yang_json_schema_for_modeled_list_entry[MiniParamEntry](
        module
    )
    print("=== parameters JSON Schema (OpenRouterFunction.Parameters) ===")
    print(params_schema)

    var name_leaf = YangLeaf[YangEnum["echo"]]()
    name_leaf.value = String("echo")
    var args_leaf = YangLeaf[
        YangBuiltinString, YangConstraints[MaxStringLength[4096]]
    ]()
    args_leaf.value = String(
        '{"ping":"hello","inner_params":{"count":5},"pong":3}'
    )
    var fn_inst = MiniFn(name=name_leaf^, arguments=args_leaf^)
    print("\n=== OpenRouterFunction instance JSON ===")
    print(json_from_modeled_instance(fn_inst, module).to_string())

    var inst = MiniParamsTemplate(
        values=(
            String("hello"),
            InnerBody(values=(5,)),
            3,
        )
    )
    print("\n=== template container instance IR (to_ast) ===")
    print(inst.to_ast().format(0))
