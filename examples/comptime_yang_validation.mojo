## Toy “thermostat service” with **type-level YANG hints** on fields and a matching
## **JSON Schema + `x-yang` tree** that is parsed through `parse_yang_json_module`
## at **compile time**. If the JSON shape drifts from what the validator accepts,
## this file fails to compile.
##
## `ThermostatApp` / `ThermostatSystem` are checked with **reflection** against the
## embedded schema: `Yang.comptime_validate` walks **`YangModule`** (effective leaves)
## and `reflect[Self]()` field names/types (see `examples/trait_self.mojo`). Each
## `YangLeaf` field gets its YANG leaf name from the Mojo member variable name;
## builtins and length caps must match the module.
##
##   pixi run package
##   export MODULAR_MOJO_IMPORT_PATH="$PWD/.pixi/envs/default/lib/mojo"
##   pixi run mojo -I build -I "$MODULAR_MOJO_IMPORT_PATH" examples/comptime_yang_validation.mojo

from std.collections import Dict, List
from std.reflection import reflect

from xyang.json import parse_yang_json_module
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import `leaf`


## --- Optional string length caps (JSON `maxLength` → YANG `length` upper bound).


trait StringLengthCap:
    @staticmethod
    def model_max_string_length() -> Int:
        ...


@fieldwise_init
struct NoStringConstraints(
    Copyable,
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    StringLengthCap,
    Writable,
):
    @staticmethod
    def model_max_string_length() -> Int:
        return -1


@fieldwise_init
struct MaxStringLength[
    n: Int,
](
    Copyable,
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    StringLengthCap,
    Writable,
):
    @staticmethod
    def model_max_string_length() -> Int:
        return Self.n


## --- Type-level YANG metadata (paths + constraints for reflection) ----------
##
## Builtin YANG types are **marker structs** implementing `YangBuiltinDescriptor`:
## they supply the RFC keyword (`yang_type_keyword`) and **`comptime Value`**, the
## Mojo type for `YangLeaf.value` (no parallel `StringLiteral` + `Value` params).
## Add more builtins with another empty `@fieldwise_init` struct, `comptime Value = …`,
## and `yang_type_keyword()`.


trait YangBuiltinDescriptor:
    comptime Value: Writable & Copyable & Movable & ImplicitlyDestructible & Defaultable

    @staticmethod
    def yang_type_keyword() -> String:
        ...


@fieldwise_init
struct YangBuiltinString(
    Copyable,
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    Writable,
    YangBuiltinDescriptor,
):
    comptime Value = String

    @staticmethod
    def yang_type_keyword() -> String:
        return "string"


@fieldwise_init
struct YangBuiltinBool(
    Copyable,
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    Writable,
    YangBuiltinDescriptor,
):
    comptime Value = Bool

    @staticmethod
    def yang_type_keyword() -> String:
        return "boolean"


trait LeafModelSpec:
    @staticmethod
    def yang_type_str() -> String:
        ...

    @staticmethod
    def model_max_string_length() -> Int:
        ...


trait Yang:
    """YANG data subtree: supplies the container keyword argument / schema root.
    """

    @staticmethod
    def yang_container_name() -> String:
        ...

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        _validate_yang_subtree[Self](module)


@fieldwise_init
struct YangLeaf[
    Builtin: YangBuiltinDescriptor,
    Constraints: StringLengthCap,
](ImplicitlyDestructible, LeafModelSpec, Movable):
    var value: Self.Builtin.Value

    @staticmethod
    def yang_type_str() -> String:
        return Self.Builtin.yang_type_keyword()

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.Constraints.model_max_string_length()


@fieldwise_init
struct YangContainer[
    Child: Movable & ImplicitlyDestructible & Yang,
](ImplicitlyDestructible, Movable):
    var body: Self.Child

    @staticmethod
    def yang_name() -> String:
        return Self.Child.yang_container_name()


## --- Application data model (mirrors JSON `properties` / `x-yang` tree) -----


@fieldwise_init
struct ThermostatSystem(ImplicitlyDestructible, Movable, Yang):
    @staticmethod
    def yang_container_name() -> String:
        return "system"

    ## `leaf hostname { type string; … }`
    var hostname: YangLeaf[YangBuiltinString, MaxStringLength[253]]
    ## `leaf enabled { type boolean; … }`
    var enabled: YangLeaf[YangBuiltinBool, NoStringConstraints]


@fieldwise_init
struct ThermostatApp(ImplicitlyDestructible, Movable):
    ## `container system { … }` — container name comes from `ThermostatSystem` (`Yang`).
    var system: YangContainer[ThermostatSystem]


## Embedded program/schema as JSON (container + leaves with `x-yang`).

comptime APP_SCHEMA_JSON = """{
  "x-yang": {
    "module": "thermostat-app",
    "yang-version": "1.1",
    "namespace": "urn:example:thermostat-app",
    "prefix": "ta"
  },
  "description": "Toy thermostat configuration surface",
  "type": "object",
  "properties": {
    "system": {
      "type": "object",
      "description": "Device system settings",
      "x-yang": {"type": "container"},
      "properties": {
        "hostname": {
          "type": "string",
          "maxLength": 253,
          "description": "DNS hostname",
          "x-yang": {"type": "leaf"}
        },
        "enabled": {
          "type": "boolean",
          "description": "Telemetry enabled",
          "x-yang": {"type": "leaf"}
        }
      }
    }
  }
}"""


def _schema_string_max_length(
    read module: YangModule, read parent: String, read leaf: String
) raises -> Int:
    ## Upper bound implied by the module’s `length` on this leaf, or -1 if none.
    var c = module.top_container(parent)
    if not c:
        raise Error("reflection: no top container `" + parent + "`")
    var lf = module.find_effective_leaf(c.value()[], leaf)
    if not lf:
        raise Error(
            "reflection: no leaf `"
            + leaf
            + "` under container `"
            + parent
            + "`"
        )
    var segs = module.leaf_length_segments(lf.value()[])
    if len(segs) == 0:
        return -1
    var hi: Int64 = -1
    for i in range(len(segs)):
        if segs[i].hi > hi:
            hi = segs[i].hi
    comptime _BIG: Int64 = 9223372036854775807
    if hi >= _BIG:
        return -1
    return Int(hi)


def _validate_yang_subtree[T: Yang](read module: YangModule) raises:
    comptime info = reflect[T]()
    comptime _nfc = info.field_count()
    var want = T.yang_container_name()
    var c = module.top_container(want)
    if not c:
        raise Error(
            "reflection: Yang subtree missing top container `" + want + "`"
        )
    var schema_leaves = _effective_leaf_names_under(module, c.value()[])
    if len(schema_leaves) != _nfc:
        raise Error(
            "reflection: container `"
            + want
            + "` has "
            + String(len(schema_leaves))
            + " effective leaf(es) vs "
            + String(_nfc)
            + " model field(s)"
        )
    for i in range(len(schema_leaves)):
        var ln = schema_leaves[i]
        var in_model = False
        for j in range(_nfc):
            if info.field_names()[j] == ln:
                in_model = True
                break
        if not in_model:
            raise Error(
                "reflection: schema leaf `"
                + want
                + "/"
                + ln
                + "` has no matching Mojo field"
            )
    comptime for j in range(_nfc):
        var fname = String(info.field_names()[j])
        var in_schema = False
        for i in range(len(schema_leaves)):
            if schema_leaves[i] == fname:
                in_schema = True
                break
        if not in_schema:
            raise Error(
                "reflection: Mojo field `"
                + fname
                + "` missing under YANG `"
                + want
                + "`"
            )
        _validate_leaf_field_type_vs_module[info.field_types()[j]](
            module, want, fname
        )


def _validate_leaf_field_type_vs_module[
    FT: AnyType,
](read module: YangModule, read parent: String, read leaf: String) raises:
    ## Thin wrapper for `_validate_leaf_model_vs_module[FT]`.
    _validate_leaf_model_vs_module[FT](module, parent, leaf)


def _validate_leaf_model_vs_module[
    FT: AnyType
](read module: YangModule, read parent: String, read leaf: String) raises:
    var reflected_ty = reflect[FT]().name()
    var string_marker = reflect[YangBuiltinString]().name()
    var bool_marker = reflect[YangBuiltinBool]().name()
    var yt = "string"
    if string_marker in reflected_ty:
        pass
    elif bool_marker in reflected_ty:
        yt = "boolean"
    else:
        raise Error(
            "reflection: field `"
            + parent
            + "/"
            + leaf
            + "` is not a recognized YangLeaf builtin: "
            + reflected_ty
        )
    var c = module.top_container(parent)
    if not c:
        raise Error("reflection: missing container `" + parent + "`")
    var lf = module.find_effective_leaf(c.value()[], leaf)
    if not lf:
        raise Error("reflection: missing leaf `" + parent + "/" + leaf + "`")
    var schema_ty = module.leaf_type(lf.value()[])
    if schema_ty != yt:
        raise Error(
            "reflection: leaf `"
            + parent
            + "/"
            + leaf
            + "` model type `"
            + yt
            + "` != schema `"
            + schema_ty
            + "`"
        )
    if yt == "string":
        var schema_max = _schema_string_max_length(module, parent, leaf)
        var want_constraint = "MaxStringLength[" + String(schema_max) + "]"
        if schema_max == -1:
            want_constraint = reflect[NoStringConstraints]().name()
        if want_constraint not in reflected_ty:
            raise Error(
                "reflection: leaf `"
                + parent
                + "/"
                + leaf
                + "` model constraints `"
                + reflected_ty
                + "` do not match schema length upper bound "
                + String(schema_max)
            )
    else:
        if reflect[NoStringConstraints]().name() not in reflected_ty:
            raise Error(
                "reflection: non-string leaf `"
                + parent
                + "/"
                + leaf
                + "` must use NoStringConstraints (max -1)"
            )


def _effective_leaf_names_under(
    read module: YangModule, read parent: YangConstruct
) raises -> List[String]:
    ## Effective `leaf` names under `parent`, including via `uses` (mirrors
    ## `YangModule.effective_data_children` but only leaves).
    var out = List[String]()
    var seen = Dict[String, Bool]()
    for child in parent.children:
        if child[].spec == `leaf` and child[].argument:
            var name = child[].argument.value()
            if name not in seen:
                seen[name] = True
                out.append(name)
    for child in parent.children:
        if child[].keyword != "uses" or not child[].argument:
            continue
        var grouping = module.find_grouping(child[].argument.value())
        if not grouping:
            continue
        var inner = _effective_leaf_names_under(module, grouping.value()[])
        for i in range(len(inner)):
            var n = inner[i]
            if n not in seen:
                seen[n] = True
                out.append(n)
    return out^


def _validate_mojo_model_vs_yang(read module: YangModule) raises:
    ## `ThermostatApp` holds `YangContainer[ThermostatSystem]`; subtree checks live on
    ## `ThermostatSystem.comptime_validate` (`Yang` trait).
    ThermostatSystem.comptime_validate(module)


## Lock: embedded JSON is parsed + validated while compiling this module.
def _embedded_schema_parse_ok() -> Bool:
    try:
        _ = parse_yang_json_module(
            String(APP_SCHEMA_JSON), "thermostat-app.json"
        )
        return True
    except:
        return False


comptime _THERMOSTAT_SCHEMA_OK: Bool = _embedded_schema_parse_ok()


def _reflection_matches_schema_ok() -> Bool:
    try:
        var m = parse_yang_json_module(
            String(APP_SCHEMA_JSON), "thermostat-app.json"
        )
        _validate_mojo_model_vs_yang(m)
        return True
    except:
        return False


comptime _THERMOSTAT_REFLECTION_OK: Bool = _reflection_matches_schema_ok()


def main() raises:
    comptime assert _THERMOSTAT_SCHEMA_OK, (
        "examples/comptime_yang_validation.mojo: embedded APP_SCHEMA_JSON"
        " failed JSON parse or YANG construct validation"
    )
    comptime assert _THERMOSTAT_REFLECTION_OK, (
        "examples/comptime_yang_validation.mojo: ThermostatApp/ThermostatSystem"
        " fields do not match APP_SCHEMA_JSON (reflection vs YangModule)"
    )
    var module = parse_yang_json_module(
        String(APP_SCHEMA_JSON), "thermostat-app.json"
    )
    _validate_mojo_model_vs_yang(module)
    print("Comptime-checked JSON schema module: " + module.get_name())
    print(
        "Reflection: Mojo model matches schema for `"
        + YangContainer[ThermostatSystem].yang_name()
        + "` leaves `"
        + String(reflect[ThermostatSystem]().field_names()[0])
        + "` (string, max "
        + String(
            YangLeaf[
                YangBuiltinString, MaxStringLength[253]
            ].model_max_string_length()
        )
        + ") and `"
        + String(reflect[ThermostatSystem]().field_names()[1])
        + "` (boolean)."
    )
