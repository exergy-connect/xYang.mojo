## JSON/YANG parser for Mojo xYang using EmberJson.

from emberjson import parse, Value
from std.memory import ArcPointer
from xyang.ast import YangModule, YangContainer, YangLeaf, YangType

comptime Arc = ArcPointer


def parse_yang_module(source: String) -> YangModule:
    # Parse a `.yang.json` meta-model into a minimal YangModule AST.
    # This is a placeholder stub that demonstrates wiring EmberJson into the
    # xYang.mojo AST. It does **not** yet implement the full xYang meta-model.
    var root: Value = parse(source)

    # The meta-model schema stores module metadata under the "x-yang" object
    # at the top level. Guard against schemas that don't include this block.
    var name = ""
    var ns = ""
    var prefix = ""

    if "x-yang" in root.object():
        ref xyang = root.object()["x-yang"]
        name = xyang.object()["module"].string()
        ns = xyang.object()["namespace"].string()
        prefix = xyang.object()["prefix"].string()

    # Discover all top-level YANG containers generically by scanning the
    # "properties" map for entries whose x-yang.type == "container". This
    # keeps the parser independent of instance-specific names like
    # "data-model".
    var containers = List[Arc[YangContainer]]()

    for key in root.object()["properties"].object().keys():
        # Delegate parsing of each container schema node to helpers to keep
        # this function focused on module-level wiring.
        ref prop = root.object()["properties"][key]
        if not is_yang_container(prop):
            continue

        var yc = parse_yang_container(key, prop)
        containers.append(Arc[YangContainer](yc^))

    return YangModule(
        name = name,
        namespace = ns,
        prefix = prefix,
        top_level_containers = containers^,
    )


def is_yang_container(prop: Value) -> Bool:
    """Return True if the given schema property represents a YANG container."""
    if not ("x-yang" in prop.object()):
        return False

    var kind = prop.object()["x-yang"]["type"].string()
    return kind == "container"


def parse_yang_container(name: String, prop: Value) -> YangContainer:
    """Parse a single top-level container definition from a JSON Schema property.

    Preconditions:
        - Caller has verified is_yang_container(prop) == True.
    """
    # Optional description field.
    var desc = ""
    if "description" in prop.object():
        desc = prop.object()["description"].string()

    var yc = YangContainer(
        name = name,
        description = desc,
        leaves = List[Arc[YangLeaf]](),
        containers = List[Arc[YangContainer]](),
    )

    return yc^

