## Toy “thermostat service” with **type-level YANG hints** on fields and a matching
## **JSON Schema + `x-yang` tree** that is parsed through `parse_yang_json_module`
## at **compile time**. If the JSON shape drifts from what the validator accepts,
## this file fails to compile.
##
## `ThermostatApp` / `ThermostatSystem` are checked with **reflection** against the
## embedded schema: `Yang.comptime_validate` walks **`YangModule`** (effective leaves)
## and `reflect[Self]()` field names (see `examples/trait_self.mojo`), then runs type
## checks; each
## `YangLeaf` parent is `Parent.yang_container_name()` (e.g.
## `YangLeaf[Self, …]` on `ThermostatSystem`); leaf names, builtin marker
## (`YangBuiltinString` / `YangBuiltinBool` → `yang_type_keyword` + `comptime Value`),
## and optional **`MaxStringLength` / `NoStringConstraints`**, must match the indexed
## module (e.g. string `maxLength` → `length` hi).
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
    def parent_container_str() -> String:
        ...

    @staticmethod
    def leaf_name_str() -> String:
        ...

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

    ## Optional follow-up (e.g. `_validate_leaf_model_vs_module` per `YangLeaf` field);
    ## default is a no-op; runs after the **`reflect[Self]()`**-driven module walk below.
    @staticmethod
    def _yang_validate_leaf_field_types(read module: YangModule) raises:
        return

    ## Default: walk **`YangModule`** for this **`Yang`** type using **`reflect[Self]()`**
    ## for field metadata (`examples/trait_self.mojo`). **`Self` as a generic type
    ## argument** (e.g. `Foo[Self]`) still refers to the trait here; **`reflect[Self]`**
    ## resolves to the implementation struct.**
    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        comptime info = reflect[Self]()
        comptime _nfc = info.field_count()
        var want = Self.yang_container_name()
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
        for j in range(_nfc):
            var fname = info.field_names()[j]
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
        Self._yang_validate_leaf_field_types(module)


@fieldwise_init
struct YangLeaf[
    Parent: Movable & ImplicitlyDestructible & Yang,
    leaf_name: StringLiteral,
    Builtin: YangBuiltinDescriptor,
    Constraints: StringLengthCap,
](ImplicitlyDestructible, LeafModelSpec, Movable):
    var value: Self.Builtin.Value

    @staticmethod
    def parent_container_str() -> String:
        return Self.Parent.yang_container_name()

    @staticmethod
    def leaf_name_str() -> String:
        return String(Self.leaf_name)

    @staticmethod
    def yang_type_str() -> String:
        return Self.Builtin.yang_type_keyword()

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.Constraints.model_max_string_length()

    @staticmethod
    def yang_container() -> String:
        return Self.Parent.yang_container_name()

    @staticmethod
    def yang_leaf() -> String:
        return String(Self.leaf_name)


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

    @staticmethod
    def _yang_validate_leaf_field_types(read module: YangModule) raises:
        ## `Yang.comptime_validate` default already walked `YangModule` vs `reflect[Self]()`.
        _validate_leaf_fields_vs_module_thermostat(module)

    ## `leaf hostname { type string; … }` with JSON `maxLength` 253
    var hostname: YangLeaf[
        Self,
        "hostname",
        YangBuiltinString,
        MaxStringLength[253],
    ]
    ## `leaf enabled { type boolean; … }`
    var enabled: YangLeaf[
        Self,
        "enabled",
        YangBuiltinBool,
        NoStringConstraints,
    ]


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


def _validate_leaf_model_vs_module[
    FT: LeafModelSpec
](read module: YangModule) raises:
    var yt = FT.yang_type_str()
    var parent = FT.parent_container_str()
    var leaf = FT.leaf_name_str()
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
    var model_max = FT.model_max_string_length()
    if yt == "string":
        var schema_max = _schema_string_max_length(module, parent, leaf)
        if model_max != schema_max:
            raise Error(
                "reflection: leaf `"
                + parent
                + "/"
                + leaf
                + "` model max string length "
                + String(model_max)
                + " != schema length upper bound "
                + String(schema_max)
            )
    else:
        if model_max != -1:
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


def _validate_leaf_fields_vs_module_thermostat(read module: YangModule) raises:
    ## `struct_field_types` is not usable as `LeafModelSpec` here (typed `AnyType`);
    ## keep these `YangLeaf` spellings aligned with `ThermostatSystem`’s fields.
    _validate_leaf_model_vs_module[
        YangLeaf[
            ThermostatSystem,
            "hostname",
            YangBuiltinString,
            MaxStringLength[253],
        ]
    ](module)
    _validate_leaf_model_vs_module[
        YangLeaf[
            ThermostatSystem,
            "enabled",
            YangBuiltinBool,
            NoStringConstraints,
        ]
    ](module)


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
        + YangLeaf[
            ThermostatSystem,
            "hostname",
            YangBuiltinString,
            MaxStringLength[253],
        ].leaf_name_str()
        + "` (string, max "
        + String(
            YangLeaf[
                ThermostatSystem,
                "hostname",
                YangBuiltinString,
                MaxStringLength[253],
            ].model_max_string_length()
        )
        + ") and `"
        + YangLeaf[
            ThermostatSystem,
            "enabled",
            YangBuiltinBool,
            NoStringConstraints,
        ].leaf_name_str()
        + "` (boolean)."
    )
