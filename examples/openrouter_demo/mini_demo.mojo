## Minimal OpenRouterFunction demo: lower once, print instance JSON.

from xyang.api import (
    MaxStringLength,
    YangBuiltinString,
    YangConstraints,
    YangEnum,
    YangField,
    YangLeaf,
    YangList,
    YangListModel,
    json_from_modeled_instance,
    yang_module_from_model,
)

from open_router import OpenRouterFunction

comptime MINI_TOOL_DESCRIPTION = "Mini demo tool with a single string parameter."
comptime MiniParamEntry = YangListModel[
    "mini_params",
    "ping",
    YangField["ping", YangLeaf[YangBuiltinString]],
]
comptime MiniFn = OpenRouterFunction[
    "echo",
    MINI_TOOL_DESCRIPTION,
    MiniParamEntry,
]


def main() raises:
    var module = yang_module_from_model[MiniFn](
        "openrouter-mini-demo",
        "urn:example:openrouter-mini-demo",
        "omd",
    )
    var name_leaf = YangLeaf[YangEnum["echo"]]()
    name_leaf.value = String("echo")
    var args_leaf = YangLeaf[
        YangBuiltinString, YangConstraints[MaxStringLength[4096]]
    ]()
    args_leaf.value = String('{"ping":"hello"}')
    var inst = MiniFn(name=name_leaf^, arguments=args_leaf^)
    var json = json_from_modeled_instance(inst, module)
    print(json.to_string())
