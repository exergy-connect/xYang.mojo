## OpenRouter tool-calling demo in Mojo.
##
## The only Python interop here is transport glue for HTTPS. The tool schema,
## tool-call parsing, xYang validation, and local callback are all Mojo.
##
##   pixi run package
##   OPENROUTER_API_KEY=... pixi run openrouter-demo

from std.python import Python

from xyang.api import (
    MaxStringLength,
    YangBuiltinString,
    YangBuiltinUInt16,
    YangConstraints,
    YangContainer,
    YangEnum,
    YangLeaf,
    YangList,
    YangListItem,
    YangModeled,
    YangRange,
    validate_yang_subtree,
    yang_module_from_model,
)
from xyang.json import parse_json
from xyang.json.value import (
    JsonArray,
    JsonInt,
    JsonString,
    JsonValue,
    json_escape,
    json_get,
)
from xyang.validator.document import validate_data
from xyang.yang.ast.module import YangModule


comptime OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

comptime PRODUCT_TEA = "Jasmine green tea"
comptime PRODUCT_MUG = "Stoneware mug"
comptime PRODUCT_BEANS = "House espresso beans"
comptime PRODUCT_FILTER = "Paper filter pack"
comptime ProductName = YangEnum[
    PRODUCT_TEA,
    PRODUCT_MUG,
    PRODUCT_BEANS,
    PRODUCT_FILTER,
]
comptime QuantityConstraints = YangConstraints[Range=YangRange[1, 20]]
comptime ToolFunctionName = YangEnum["quote_cart_item"]
comptime ToolCallType = YangEnum["function"]


@fieldwise_init
struct QuoteRequest(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "quote_request"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    var product_name: YangLeaf[ProductName]
    var quantity: YangLeaf[YangBuiltinUInt16, QuantityConstraints]


@fieldwise_init
struct OpenRouterToolFunction(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "function"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    var name: YangLeaf[ToolFunctionName]
    var arguments: YangLeaf[
        YangBuiltinString, YangConstraints[MaxStringLength[4096]]
    ]


@fieldwise_init
struct OpenRouterToolCall(
    ImplicitlyDestructible, Movable, YangListItem, YangModeled
):
    comptime LIST_KEY = "id"

    @staticmethod
    def yang_container_name() -> String:
        return "tool_call"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var id: YangLeaf[YangBuiltinString, YangConstraints[MaxStringLength[256]]]
    var type: YangLeaf[ToolCallType]
    var function: YangContainer[OpenRouterToolFunction]


@fieldwise_init
struct OpenRouterToolCalls(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "openrouter_tool_calls"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    var tool_calls: YangList[OpenRouterToolCall]


def _python_quote(read s: String) -> String:
    return (
        "'"
        + s.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
        + "'"
    )


def _env(name: String, default_value: String = "") raises -> String:
    var os = Python.import_module("os")
    var builtins = Python.import_module("builtins")
    return String(builtins.str(os.environ.get(name, default_value)))


def _quote_module() raises -> YangModule:
    var module = yang_module_from_model[QuoteRequest](
        "openrouter-quote-tool",
        "urn:example:openrouter-quote-tool",
        "oqt",
    )
    QuoteRequest.comptime_validate(module)
    return module^


def _tool_calls_module() raises -> YangModule:
    var module = yang_module_from_model[OpenRouterToolCalls](
        "openrouter-tool-calls",
        "urn:example:openrouter-tool-calls",
        "ortc",
    )
    OpenRouterToolCalls.comptime_validate(module)
    return module^


def _product_name_enum_json() -> String:
    var out = String("[")
    comptime for i in range(ProductName.yang_enum_count()):
        if i > 0:
            out += ","
        out += '"' + json_escape(ProductName.yang_enum_value[i]()) + '"'
    out += "]"
    return out^


def _tool_parameters_json() -> String:
    return (
        '{"type":"object","additionalProperties":false,"properties":{'
        '"product_name":{"type":"string","enum":'
        + _product_name_enum_json()
        + ',"description":"Product name from the compile-time catalog."},'
        '"quantity":{"type":"integer","minimum":'
        + String(QuantityConstraints.model_range_min())
        + ',"maximum":'
        + String(QuantityConstraints.model_range_max())
        + ',"description":"Number of units to quote."}'
        '},"required":["product_name","quantity"],'
        '"x-yang":{"module":"openrouter-quote-tool","container":"'
        + QuoteRequest.yang_container_name()
        + '"}}'
    )


def _tool_schema_json() -> String:
    return (
        '{"type":"function","function":{"name":"quote_cart_item",'
        '"description":"Quote an item from the compile-time product catalog. '
        "The parameters JSON Schema is projected from the xYang modeled Mojo "
        'struct descriptors, including the product-name enum.",'
        '"parameters":'
        + _tool_parameters_json()
        + "}}"
    )


def _catalog_item(read product_name: String) raises -> Tuple[String, Int]:
    if product_name == String(PRODUCT_TEA):
        return ("tea", 450)
    if product_name == String(PRODUCT_MUG):
        return ("mug", 1200)
    if product_name == String(PRODUCT_BEANS):
        return ("beans", 1600)
    if product_name == String(PRODUCT_FILTER):
        return ("filter", 650)
    raise Error("unknown product `" + product_name + "`")


def _json_string_field(read obj: JsonValue, key: String) raises -> String:
    var value = json_get(obj, key)
    if not value or value.value()[].kind != JsonValue.STRING:
        raise Error("expected string field `" + key + "`")
    return value.value()[].payload[JsonString].value


def _json_int_field(read obj: JsonValue, key: String) raises -> Int:
    var value = json_get(obj, key)
    if not value or value.value()[].kind != JsonValue.INT:
        raise Error("expected integer field `" + key + "`")
    return Int(value.value()[].payload[JsonInt].value)


def _validate_tool_args(read module: YangModule, read args_json: String) raises:
    var wrapped = parse_json(
        '{"quote_request":' + args_json + "}", "tool-arguments.json"
    )
    validate_data(wrapped, module, "tool-arguments.json")


def quote_cart_item(read module: YangModule, read args_json: String) raises -> String:
    _validate_tool_args(module, args_json)
    var args = parse_json(args_json, "quote-cart-item-arguments.json")
    var product_name = _json_string_field(args, "product_name")
    var quantity = _json_int_field(args, "quantity")
    var item = _catalog_item(product_name)
    var subtotal = item[1] * quantity
    return (
        '{"product_name":"'
        + json_escape(product_name)
        + '","sku":"'
        + json_escape(item[0])
        + '","quantity":'
        + String(quantity)
        + ',"unit_price_cents":'
        + String(item[1])
        + ',"subtotal_cents":'
        + String(subtotal)
        + ',"currency":"USD"}'
    )


def _openrouter_chat(
    read api_key: String,
    read model: String,
    read messages_json: String,
    read tool_schema_json: String,
    include_tools: Bool,
) raises -> String:
    var body = (
        '{"model":"'
        + json_escape(model)
        + '","messages":'
        + messages_json
        + ',"temperature":0.1,"max_tokens":500'
    )
    if include_tools:
        body += (
            ',"tools":['
            + tool_schema_json
            + '],"tool_choice":"auto","parallel_tool_calls":false'
        )
    body += "}"

    var urllib = Python.import_module("urllib.request")
    var builtins = Python.import_module("builtins")
    var headers = Python().evaluate(
        "({"
        + "'Authorization': 'Bearer ' + "
        + _python_quote(api_key)
        + ", 'Content-Type': 'application/json', "
        + "'HTTP-Referer': 'https://github.com/jbemmel/xYang.mojo', "
        + "'X-Title': 'xYang Mojo OpenRouter Tool Demo'"
        + "})"
    )
    var py_body = builtins.str(body).encode("utf-8")
    var request = urllib.Request(
        String(OPENROUTER_URL), py_body, headers, None, False, "POST"
    )
    var response = urllib.urlopen(request, None, 60)
    return String(builtins.str(response.read(), encoding="utf-8"))


def _first_choice_message_json(read response: JsonValue) raises -> String:
    var choices = json_get(response, "choices")
    if not choices or choices.value()[].kind != JsonValue.ARRAY:
        raise Error("OpenRouter response missing choices array")
    ref arr = choices.value()[].payload[JsonArray].values
    if len(arr) == 0:
        raise Error("OpenRouter response has no choices")
    var message = json_get(arr[0][], "message")
    if not message or message.value()[].kind != JsonValue.OBJECT:
        raise Error("OpenRouter response missing assistant message")
    return message.value()[].to_string()


def _message_tool_calls(read message_json: String) raises -> Optional[JsonValue]:
    var message = parse_json(message_json, "assistant-message.json")
    var calls = json_get(message, "tool_calls")
    if not calls or calls.value()[].kind != JsonValue.ARRAY:
        return Optional[JsonValue]()
    return Optional[JsonValue](parse_json(calls.value()[].to_string(), "tool-calls"))


def _validate_tool_calls(
    read module: YangModule, read calls: JsonValue
) raises:
    var wrapped = parse_json(
        '{"openrouter_tool_calls":{"tool_calls":'
        + calls.to_string()
        + "}}",
        "openrouter-tool-calls.json",
    )
    validate_data(wrapped, module, "openrouter-tool-calls.json")


def _append_tool_results(
    read module: YangModule, mut messages_json: String, read calls: JsonValue
) raises -> String:
    ref arr = calls.payload[JsonArray].values
    for i in range(len(arr)):
        ref call = arr[i][]
        var call_id = _json_string_field(call, "id")
        var func_obj = json_get(call, "function")
        if not func_obj or func_obj.value()[].kind != JsonValue.OBJECT:
            raise Error("tool call missing function object")
        var name = _json_string_field(func_obj.value()[], "name")
        var args_json = _json_string_field(func_obj.value()[], "arguments")
        print("Tool call: " + name + "(" + args_json + ")")

        var result: String
        if name == "quote_cart_item":
            result = quote_cart_item(module, args_json)
        else:
            result = '{"error":"unknown tool: ' + json_escape(name) + '"}'
        print("Validated callback result: " + result)

        messages_json += (
            ',{"role":"tool","tool_call_id":"'
            + json_escape(call_id)
            + '","name":"'
            + json_escape(name)
            + '","content":"'
            + json_escape(result)
            + '"}'
        )
    return messages_json


def main() raises:
    var api_key = _env("OPENROUTER_API_KEY")
    if api_key.byte_length() == 0:
        raise Error("Set OPENROUTER_API_KEY before running this demo.")
    var model = _env("OPENROUTER_MODEL", "openrouter/free")
    var quote_module = _quote_module()
    var tool_calls_module = _tool_calls_module()
    var tool_schema_json = _tool_schema_json()

    var prompt = (
        "Quote 3 Stoneware mug items from the catalog. Use the available tool."
    )
    print("Model: " + model)
    print("User: " + prompt)
    print("")

    var messages_json = (
        '[{"role":"system","content":"You are a concise shopping assistant. '
        "Use tools for catalog quotes instead of estimating prices."
        '"},{"role":"user","content":"'
        + json_escape(prompt)
        + '"}'
    )
    print("Derived tool parameters JSON Schema:")
    print(_tool_parameters_json())
    print("")

    var first_text = _openrouter_chat(
        api_key, model, messages_json + "]", tool_schema_json, True
    )
    var first = parse_json(first_text, "openrouter-first-response.json")
    var assistant_message_json = _first_choice_message_json(first)
    messages_json += "," + assistant_message_json

    var calls = _message_tool_calls(assistant_message_json)
    if not calls:
        print("The model did not request a tool call. Raw response:")
        print(first_text)
        return

    _validate_tool_calls(tool_calls_module, calls.value())
    messages_json = _append_tool_results(quote_module, messages_json, calls.value())
    var final_text = _openrouter_chat(
        api_key, model, messages_json + "]", tool_schema_json, True
    )
    var final = parse_json(final_text, "openrouter-final-response.json")
    var final_message = parse_json(
        _first_choice_message_json(final), "openrouter-final-message.json"
    )
    var content = json_get(final_message, "content")
    print("")
    print("Assistant:")
    if content and content.value()[].kind == JsonValue.STRING:
        print(content.value()[].payload[JsonString].value)
    else:
        print(final_message.to_string())
