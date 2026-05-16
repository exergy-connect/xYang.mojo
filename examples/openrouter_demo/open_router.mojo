## OpenRouter tool-call wire models (YANG-backed) shared by the demo.
##
## Parametric `tool_name` is spelled `tool_name` (not `name`) so it does not
## shadow the modeled `function` leaf field `name`, which must stay `name` for
## correct YANG / JSON keys.

from std.memory import ArcPointer

from xyang.api import (
    JsonFromYangWalkInstance,
    LeafModelSpec,
    MaxStringLength,
    YangBuiltinDescriptor,
    YangBuiltinString,
    YangConstraints,
    YangContainer,
    YangEnum,
    YangField,
    YangLeaf,
    YangList,
    YangListItem,
    YangListModel,
    YangModel,
    YangModeled,
    YangModuleSketch,
    container_construct_from_model,
    list_construct_from_entry,
    validate_yang_subtree,
    validate_yang_subtree_list,
)
from xyang.json.value import JsonPayload, JsonString, JsonValue
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule

comptime Arc = ArcPointer


def _append_top_level_container[
    T: YangModeled
](mut module_root: YangConstruct) raises:
    module_root.children.append(
        Arc[YangConstruct](container_construct_from_model[T]()^)
    )


def _append_top_level_list[
    Entry: YangListItem
](mut module_root: YangConstruct) raises:
    module_root.children.append(
        Arc[YangConstruct](list_construct_from_entry[Entry]()^)
    )


def _json_string_value_from_yang_leaf_field[
    B: YangBuiltinDescriptor,
    C: LeafModelSpec,
](read leaf: YangLeaf[B, C]) raises -> JsonValue:
    """Leaf values that serialize as JSON strings (e.g. string and enumeration).
    """

    return JsonValue(
        JsonValue.STRING,
        JsonPayload(JsonString(value=String(leaf.value))),
        0,
    )


comptime OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"


trait OpenRouterToolCallback(Movable):
    """Application hook invoked when the model calls this tool."""

    @staticmethod
    def invoke(
        read module: YangModule, read args_json: String
    ) raises -> String:
        ...


@fieldwise_init
struct OpenRouterFunction[
    tool_name: StaticString,
    Description: StaticString,
    ParametersEntry: YangListItem,
](
    Defaultable,
    ImplicitlyDestructible,
    JsonFromYangWalkInstance,
    Movable,
    YangModeled,
    YangModuleSketch,
):
    """OpenRouter `function` object: `name` + stringified `arguments`."""

    comptime Parameters = YangList[Self.ParametersEntry]

    comptime Schema = YangModel[
        "function",
        YangField["name", YangLeaf[YangEnum[Self.tool_name]]],
        YangField[
            "arguments",
            YangLeaf[
                YangBuiltinString,
                YangConstraints[MaxStringLength[4096]],
            ],
        ],
    ]

    @staticmethod
    def yang_container_name() -> String:
        return Self.Schema.yang_container_name()

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)
        validate_yang_subtree_list[Self.ParametersEntry](module)

    @staticmethod
    def append_containers_to_module(mut module_root: YangConstruct) raises:
        _append_top_level_container[Self](module_root)
        _append_top_level_list[Self.ParametersEntry](module_root)

    @staticmethod
    def field_count() -> Int:
        return Self.Schema.field_count()

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Schema.field_name[i]()

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        Self.Schema.append_model_fields(parent)

    var name: YangLeaf[YangEnum[Self.tool_name]]
    var arguments: YangLeaf[
        YangBuiltinString, YangConstraints[MaxStringLength[4096]]
    ]

    def __init__(out self):
        self.name = YangLeaf[YangEnum[Self.tool_name]]()
        self.arguments = YangLeaf[
            YangBuiltinString, YangConstraints[MaxStringLength[4096]]
        ]()

    def json_leaf_value(read self, read leaf_name: String) raises -> JsonValue:
        if leaf_name == "name":
            return _json_string_value_from_yang_leaf_field(self.name)
        if leaf_name == "arguments":
            return _json_string_value_from_yang_leaf_field(self.arguments)
        raise Error("unknown leaf `" + leaf_name + "` for OpenRouterFunction")

    def json_nested_value(
        read self,
        read child_keyword: String,
        read child_name: String,
        read module: YangModule,
        read child_node: YangConstruct,
    ) raises -> JsonValue:
        _ = self
        _ = module
        _ = child_node
        raise Error(
            "json_from_modeled_instance: nested `"
            + child_keyword
            + "` `"
            + child_name
            + "` is not implemented for OpenRouterFunction",
        )


@fieldwise_init
struct OpenRouterTool[
    tool_name: StaticString,
    Description: StaticString,
    ParametersEntry: YangListItem,
    Callback: OpenRouterToolCallback,
](ImplicitlyDestructible, Movable, YangModeled):
    comptime Parameters = YangList[Self.ParametersEntry]
    """One OpenRouter `tools[]` entry: `{ "type": "function", "function": … }`.
    """

    comptime Schema = YangModel[
        "openrouter_tool",
        YangField["type", YangLeaf[YangEnum["function"]]],
        YangField[
            "function",
            YangContainer[
                OpenRouterFunction[
                    Self.tool_name, Self.Description, Self.Parameters
                ]
            ],
        ],
    ]

    @staticmethod
    def yang_container_name() -> String:
        return Self.Schema.yang_container_name()

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
        Self.Schema.append_model_fields(parent)

    var type: YangLeaf[YangEnum["function"]]
    var function: YangContainer[
        OpenRouterFunction[Self.tool_name, Self.Description, Self.Parameters]
    ]


@fieldwise_init
struct OpenRouterToolCall[
    tool_name: StaticString,
    Description: StaticString,
    ParametersEntry: YangListItem,
    Callback: OpenRouterToolCallback,
](ImplicitlyDestructible, Movable, YangListItem):
    comptime Parameters = YangList[Self.ParametersEntry]
    comptime LIST_KEY = "id"
    comptime Schema = YangListModel[
        "tool_call",
        Self.LIST_KEY,
        YangField[
            "id",
            YangLeaf[
                YangBuiltinString,
                YangConstraints[MaxStringLength[256]],
            ],
        ],
        YangField["type", YangLeaf[YangEnum["function"]]],
        YangField[
            "function",
            YangContainer[
                OpenRouterFunction[
                    Self.tool_name, Self.Description, Self.Parameters
                ]
            ],
        ],
    ]

    @staticmethod
    def yang_container_name() -> String:
        return Self.Schema.yang_container_name()

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    @staticmethod
    def field_count() -> Int:
        return Self.Schema.field_count()

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Schema.field_name[i]()

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        Self.Schema.append_model_fields(parent)

    var id: YangLeaf[YangBuiltinString, YangConstraints[MaxStringLength[256]]]
    var type: YangLeaf[YangEnum["function"]]
    var function: YangContainer[
        OpenRouterFunction[Self.tool_name, Self.Description, Self.Parameters]
    ]


@fieldwise_init
struct OpenRouterToolCalls[
    tool_name: StaticString,
    Description: StaticString,
    ParametersEntry: YangListItem,
    Callback: OpenRouterToolCallback,
](ImplicitlyDestructible, Movable, YangModeled):
    comptime Parameters = YangList[Self.ParametersEntry]
    comptime Schema = YangModel[
        "openrouter_tool_calls",
        YangField[
            "tool_calls",
            YangList[
                OpenRouterToolCall[
                    Self.tool_name,
                    Self.Description,
                    Self.Parameters,
                    Self.Callback,
                ]
            ],
        ],
    ]

    @staticmethod
    def yang_container_name() -> String:
        return Self.Schema.yang_container_name()

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
        Self.Schema.append_model_fields(parent)

    var tool_calls: YangList[
        OpenRouterToolCall[
            Self.tool_name, Self.Description, Self.Parameters, Self.Callback
        ]
    ]
