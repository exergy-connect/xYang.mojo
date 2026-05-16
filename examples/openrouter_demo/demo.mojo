## OpenRouter tool-calling demo in Mojo.
##
## The only Python interop here is transport glue for HTTPS. The tool schema,
## tool-call parsing, xYang validation, and local callback are all Mojo.
##
##   pixi run package
##   OPENROUTER_API_KEY=... pixi run openrouter-demo

from std.collections import List
from std.memory import ArcPointer
from std.python import Python

from xyang.api import (
    YangBuiltinString,
    YangBuiltinUInt16,
    YangConstraints,
    YangEnum,
    YangLeaf,
    YangModeled,
    YangRange,
    json_from_modeled_instance,
    validate_yang_subtree,
    yang_module_from_model,
)
from xyang.json import parse_json, yang_json_schema_for_modeled_top_container
from xyang.json.value import (
    JsonArray,
    JsonInt,
    JsonObject,
    JsonPayload,
    JsonString,
    JsonValue,
    json_escape,
    json_get,
)
from xyang.validator.document import validate_data
from xyang.yang.ast.module import YangModule

from open_router import (
    OPENROUTER_URL,
    OpenRouterFunction,
    OpenRouterToolCallback,
    OpenRouterToolCalls,
)


comptime Arc = ArcPointer


def _openrouter_tool_definition_value(
    read inner_function_data: JsonValue,
    read description: String,
    var parameters_schema: JsonValue,
) raises -> JsonValue:
    var name_slot = json_get(inner_function_data, "name")
    if not name_slot or name_slot.value()[].kind != JsonValue.STRING:
        raise Error("json_from_instance result missing string `name`")
    var tool_name_str = name_slot.value()[].payload[JsonString].value
    var fn_keys = List[String]()
    var fn_vals = List[Arc[JsonValue]]()
    fn_keys.append("name")
    fn_vals.append(
        Arc[JsonValue](
            JsonValue(
                JsonValue.STRING,
                JsonPayload(JsonString(value=tool_name_str.copy())),
                0,
            )
        )
    )
    fn_keys.append("description")
    fn_vals.append(
        Arc[JsonValue](
            JsonValue(
                JsonValue.STRING,
                JsonPayload(JsonString(value=String(description))),
                0,
            )
        )
    )
    fn_keys.append("parameters")
    fn_vals.append(Arc[JsonValue](parameters_schema^))
    var fn_obj = JsonValue(
        JsonValue.OBJECT,
        JsonPayload(JsonObject(keys=fn_keys^, values=fn_vals^)),
        0,
    )
    var out_keys = List[String]()
    var out_vals = List[Arc[JsonValue]]()
    out_keys.append("type")
    out_vals.append(
        Arc[JsonValue](
            JsonValue(
                JsonValue.STRING,
                JsonPayload(JsonString(value=String("function"))),
                0,
            )
        )
    )
    out_keys.append("function")
    out_vals.append(Arc[JsonValue](fn_obj^))
    return JsonValue(
        JsonValue.OBJECT,
        JsonPayload(JsonObject(keys=out_keys^, values=out_vals^)),
        0,
    )


comptime PRODUCT_TEA = "jasmine-green-tea"
comptime PRODUCT_MUG = "stoneware-mug"
comptime PRODUCT_BEANS = "house-espresso-beans"
comptime PRODUCT_FILTER = "paper-filter-pack"
comptime ProductName = YangEnum[
    PRODUCT_TEA,
    PRODUCT_MUG,
    PRODUCT_BEANS,
    PRODUCT_FILTER,
]
comptime QuantityConstraints = YangConstraints[Range=YangRange[1, 20]]

comptime DEMO_OPENROUTER_TOOL_DESCRIPTION = (
    "OpenRouter `function` object modeled as `function` for tool "
    "`quote_cart_item`. The `parameters` JSON Schema is projected from "
    "`quote_request`. Put that object as JSON text in the `arguments` string; "
    "this demo validates it against the quote YANG module after parsing the "
    "tool call."
)


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
    var module = yang_module_from_model[DemoOpenRouterToolCalls](
        "openrouter-tool-calls",
        "urn:example:openrouter-tool-calls",
        "ortc",
    )
    DemoOpenRouterToolCalls.comptime_validate(module)
    return module^


def _tool_function_yang_module[
    tool_name: StaticString,
    description: StaticString,
    Parameters: YangModeled,
]() raises -> YangModule:
    comptime Fn = OpenRouterFunction[tool_name, description, Parameters]
    return yang_module_from_model[Fn](
        "openrouter-tool-function-schema",
        "urn:example:openrouter-tool-function-schema",
        "otfns",
    )


def openrouter_tool_function_tool_json[
    tool_name: StaticString,
    description: StaticString,
    Parameters: YangModeled,
]() raises -> Tuple[String, String]:
    comptime Fn = OpenRouterFunction[tool_name, description, Parameters]
    var m_fn = _tool_function_yang_module[tool_name, description, Parameters]()
    Fn.comptime_validate(m_fn)
    var inst = Fn()
    inst.name.value = String(tool_name)
    var inner = json_from_modeled_instance[Fn](inst, m_fn)
    var m_params = yang_module_from_model[Parameters](
        "openrouter-quote-tool",
        "urn:example:openrouter-quote-tool",
        "oqt",
    )
    Parameters.comptime_validate(m_params)
    var params = yang_json_schema_for_modeled_top_container[Parameters](
        m_params
    )
    var params_value = parse_json(
        params, "openrouter-tool-parameters-schema.json"
    )
    var tool_v = _openrouter_tool_definition_value(
        inner, String(description), params_value^
    )
    var entry = tool_v.to_string()
    return Tuple[String, String](entry^, params^)


def _catalog_item(read product_name: String) raises -> Tuple[String, Int]:
    if product_name == String(PRODUCT_TEA):
        return ("Jasmine green tea", 450)
    if product_name == String(PRODUCT_MUG):
        return ("Stoneware mug", 1200)
    if product_name == String(PRODUCT_BEANS):
        return ("House espresso beans", 1600)
    if product_name == String(PRODUCT_FILTER):
        return ("Paper filter pack", 650)
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


def quote_cart_item(
    read module: YangModule, read args_json: String
) raises -> String:
    _validate_tool_args(module, args_json)
    var args = parse_json(args_json, "quote-cart-item-arguments.json")
    var product_name = _json_string_field(args, "product_name")
    var quantity = _json_int_field(args, "quantity")
    var item = _catalog_item(product_name)
    var subtotal = item[1] * quantity
    return (
        '{"product_name":"'
        + json_escape(product_name)
        + '","name":"'
        + json_escape(item[0])
        + '","quantity":'
        + String(quantity)
        + ',"unit_price_cents":'
        + String(item[1])
        + ',"subtotal_cents":'
        + String(subtotal)
        + ',"currency":"USD"}'
    )


@fieldwise_init
struct QuoteCartItemToolCallback(Movable, OpenRouterToolCallback):
    @staticmethod
    def invoke(
        read module: YangModule, read args_json: String
    ) raises -> String:
        return quote_cart_item(module, args_json)


comptime DemoOpenRouterToolCalls = OpenRouterToolCalls[
    "quote_cart_item",
    DEMO_OPENROUTER_TOOL_DESCRIPTION,
    QuoteRequest,
    QuoteCartItemToolCallback,
]


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


def _message_tool_calls(
    read message_json: String,
) raises -> Optional[JsonValue]:
    var message = parse_json(message_json, "assistant-message.json")
    var calls = json_get(message, "tool_calls")
    if not calls or calls.value()[].kind != JsonValue.ARRAY:
        return Optional[JsonValue]()
    return Optional[JsonValue](
        parse_json(calls.value()[].to_string(), "tool-calls")
    )


def _validate_tool_calls(read module: YangModule, read calls: JsonValue) raises:
    var wrapped = parse_json(
        '{"openrouter_tool_calls":{"tool_calls":' + calls.to_string() + "}}",
        "openrouter-tool-calls.json",
    )
    validate_data(wrapped, module, "openrouter-tool-calls.json")


def _append_tool_results[
    tool_name: StaticString,
    description: StaticString,
    Parameters: YangModeled,
    Callback: OpenRouterToolCallback,
](
    read module: YangModule,
    mut messages_json: String,
    read calls: JsonValue,
) raises -> String:
    ref arr = calls.payload[JsonArray].values
    for i in range(len(arr)):
        ref call = arr[i][]
        var call_id = _json_string_field(call, "id")
        var func_obj = json_get(call, "function")
        if not func_obj or func_obj.value()[].kind != JsonValue.OBJECT:
            raise Error("tool call missing function object")
        var invoked_name = _json_string_field(func_obj.value()[], "name")
        var args_json = _json_string_field(func_obj.value()[], "arguments")
        print("Tool call: " + invoked_name + "(" + args_json + ")")

        var result: String
        if invoked_name == String(tool_name):
            result = Callback.invoke(module, args_json)
        else:
            result = (
                '{"error":"unknown tool: ' + json_escape(invoked_name) + '"}'
            )
        print("Validated callback result: " + result)

        messages_json += (
            ',{"role":"tool","tool_call_id":"'
            + json_escape(call_id)
            + '","name":"'
            + json_escape(invoked_name)
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
    var tool_json = openrouter_tool_function_tool_json[
        "quote_cart_item",
        DEMO_OPENROUTER_TOOL_DESCRIPTION,
        QuoteRequest,
    ]()
    var tool_schema_json = tool_json[0]

    var prompt = (
        "Quote 3 stoneware-mug items from the catalog. Use the available tool."
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
    print(tool_json[1])
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
    messages_json = _append_tool_results[
        "quote_cart_item",
        DEMO_OPENROUTER_TOOL_DESCRIPTION,
        QuoteRequest,
        QuoteCartItemToolCallback,
    ](
        quote_module,
        messages_json,
        calls.value(),
    )
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
