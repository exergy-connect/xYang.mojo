## OpenRouter tool-call wire models (YANG-backed) shared by the demo.
##
## Parametric `tool_name` is spelled `tool_name` (not `name`) so it does not
## shadow the modeled `function` leaf field `name`, which must stay `name` for
## correct YANG / JSON keys.

from xyang.api import (
    JsonFromYangWalkInstance,
    LeafModelSpec,
    MaxStringLength,
    YangBuiltinDescriptor,
    YangBuiltinString,
    YangConstraints,
    YangContainer,
    YangEnum,
    YangLeaf,
    YangList,
    YangListItem,
    YangModeled,
    validate_yang_subtree,
)
from xyang.json.value import JsonPayload, JsonString, JsonValue
from xyang.yang.ast.module import YangModule


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
    Parameters: YangModeled,
](
    Defaultable,
    ImplicitlyDestructible,
    JsonFromYangWalkInstance,
    Movable,
    YangModeled,
):
    """OpenRouter `function` object: `name` + stringified `arguments`."""

    @staticmethod
    def yang_container_name() -> String:
        return "function"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

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


@fieldwise_init
struct OpenRouterTool[
    tool_name: StaticString,
    Description: StaticString,
    Parameters: YangModeled,
    Callback: OpenRouterToolCallback,
](ImplicitlyDestructible, Movable, YangModeled):
    """One OpenRouter `tools[]` entry: `{ "type": "function", "function": … }`.
    """

    @staticmethod
    def yang_container_name() -> String:
        return "openrouter_tool"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    var type: YangLeaf[YangEnum["function"]]
    var function: YangContainer[
        OpenRouterFunction[Self.tool_name, Self.Description, Self.Parameters]
    ]


@fieldwise_init
struct OpenRouterToolCall[
    tool_name: StaticString,
    Description: StaticString,
    Parameters: YangModeled,
    Callback: OpenRouterToolCallback,
](ImplicitlyDestructible, Movable, YangListItem):
    comptime LIST_KEY = "id"

    @staticmethod
    def yang_container_name() -> String:
        return "tool_call"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var id: YangLeaf[YangBuiltinString, YangConstraints[MaxStringLength[256]]]
    var type: YangLeaf[YangEnum["function"]]
    var function: YangContainer[
        OpenRouterFunction[Self.tool_name, Self.Description, Self.Parameters]
    ]


@fieldwise_init
struct OpenRouterToolCalls[
    tool_name: StaticString,
    Description: StaticString,
    Parameters: YangModeled,
    Callback: OpenRouterToolCallback,
](ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "openrouter_tool_calls"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    var tool_calls: YangList[
        OpenRouterToolCall[
            Self.tool_name, Self.Description, Self.Parameters, Self.Callback
        ]
    ]
